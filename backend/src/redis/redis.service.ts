import { Injectable, OnModuleDestroy, OnModuleInit, Logger } from '@nestjs/common';
import Redis from 'ioredis';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Low-level Redis client wrapper.
 *
 * Responsibilities:
 *  - WebSocket session state       (userId ↔ socketId mapping)
 *  - Rate-limiting buckets         (sliding-window counters per user/IP)
 *  - Emoji reaction counts         (fast atomic increments per memory)
 *  - Refresh token allowlist       (per-user SET of active JTIs for revocation)
 *  - One-time WebSocket tickets    (short-lived opaque upgrade credentials)
 */

/** 30 days in seconds — matches refresh token JWT expiry. */
const REFRESH_TOKEN_TTL_SECONDS = 60 * 60 * 24 * 30;
@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private client: Redis;

  constructor(private readonly prisma: PrismaService) {}

  // ─── Key prefixes ──────────────────────────────────────────────────────────
  private readonly PREFIX_SOCKET   = 'ws:socket:';   // ws:socket:<userId>      → socketId
  private readonly PREFIX_USER     = 'ws:user:';     // ws:user:<socketId>      → userId
  private readonly PREFIX_RL       = 'rl:';          // rl:<userId|ip>          → hit count
  private readonly PREFIX_REACT    = 'react:';       // react:<memoryId>:<emoji> → count
  private readonly PREFIX_RT       = 'rt:';          // rt:<userId>             → SET of active JTIs
  private readonly PREFIX_RTMETA   = 'rtmeta:';      // rtmeta:<userId>:<jti>   → JSON metadata
  private readonly PREFIX_TICKET   = 'ws:ticket:';   // ws:ticket:<ticket>      → {userId,username} (TTL 30s)

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  onModuleInit() {
    this.client = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379', {
      maxRetriesPerRequest: 3,
      enableReadyCheck: true,
    });

    this.client.on('connect', () => this.logger.log('Redis connected'));
    this.client.on('error',   (err) => this.logger.error('Redis error', err));

    // Periodically flush reactions to database every 15 minutes
    setInterval(() => {
      this.flushReactionsToDb().catch((err) => {
        this.logger.error(`[Background Job] Failed to flush reactions to DB: ${err.message}`);
      });
    }, 1000 * 60 * 15);
  }

  async onModuleDestroy() {
    if (this.client) {
      await this.client.quit();
    }
  }

  // ─── WebSocket session state ───────────────────────────────────────────────

  /** Register an active WebSocket connection for a user. TTL = 24 h. */
  async setSocketSession(userId: string, socketId: string): Promise<void> {
    const ttl = 60 * 60 * 24; // 24 hours
    await Promise.all([
      this.client.setex(`${this.PREFIX_SOCKET}${userId}`, ttl, socketId),
      this.client.setex(`${this.PREFIX_USER}${socketId}`, ttl, userId),
    ]);
  }

  /** Look up the active socketId for a given userId. */
  async getSocketId(userId: string): Promise<string | null> {
    return this.client.get(`${this.PREFIX_SOCKET}${userId}`);
  }

  /** Look up the userId for a given socketId. */
  async getUserId(socketId: string): Promise<string | null> {
    return this.client.get(`${this.PREFIX_USER}${socketId}`);
  }

  /** Remove both mappings when a user disconnects. */
  async removeSocketSession(socketId: string): Promise<void> {
    const userId = await this.getUserId(socketId);
    const keys: string[] = [`${this.PREFIX_USER}${socketId}`];
    if (userId) keys.push(`${this.PREFIX_SOCKET}${userId}`);
    await this.client.del(...keys);
  }

  /** Return all currently connected user IDs (scans active ws:socket:* keys using SCAN cursor iteration). */
  async getOnlineUserIds(): Promise<string[]> {
    const stream = this.client.scanStream({
      match: `${this.PREFIX_SOCKET}*`,
      count: 100,
    });

    const userIds = new Set<string>();

    return new Promise<string[]>((resolve, reject) => {
      stream.on('data', (keys: string[]) => {
        for (const key of keys) {
          userIds.add(key.replace(this.PREFIX_SOCKET, ''));
        }
      });
      stream.on('end', () => {
        resolve(Array.from(userIds));
      });
      stream.on('error', (err) => {
        reject(err);
      });
    });
  }

  // ─── Rate-limiting buckets ─────────────────────────────────────────────────

  /**
   * Sliding-window rate limiter.
   * Returns the current hit count after incrementing.
   * The bucket key is set to expire after `windowSeconds` on first hit.
   */
  async rateLimit(
    identifier: string,
    windowSeconds: number,
  ): Promise<{ count: number; ttl: number }> {
    const key = `${this.PREFIX_RL}${identifier}`;
    const pipeline = this.client.pipeline();
    pipeline.incr(key);
    pipeline.ttl(key);
    const results = await pipeline.exec();

    // results[0] = [err, count], results[1] = [err, ttl]
    const count = results?.[0]?.[1] as number;
    const ttl   = results?.[1]?.[1] as number;

    // Set expiry only on the first hit (ttl === -1 means no expiry set yet)
    if (ttl === -1) {
      await this.client.expire(key, windowSeconds);
    }

    return { count, ttl: ttl === -1 ? windowSeconds : ttl };
  }

  /** Reset a rate-limit bucket (e.g. after a successful auth). */
  async resetRateLimit(identifier: string): Promise<void> {
    await this.client.del(`${this.PREFIX_RL}${identifier}`);
  }

  // ─── Emoji reaction counts ─────────────────────────────────────────────────
  //
  // Emoji reaction counts are stored inside a Redis HASH per memory:
  //   react:<memoryId> → { <emoji>: <count> }
  //
  // This layout makes retrieval (HGETALL) and clearing (DEL) O(1) operations,
  // completely avoiding any performance-killing KEYS scan.

  /** Atomically increment an emoji reaction count for a memory. */
  async incrementReaction(memoryId: string, emoji: string): Promise<number> {
    const key = `${this.PREFIX_REACT}${memoryId}`;
    await this.ensureReactionsLoaded(memoryId);
    return this.client.hincrby(key, emoji, 1);
  }

  /** Decrement (remove one reaction) — floors at 0 atomically via Lua. */
  async decrementReaction(memoryId: string, emoji: string): Promise<number> {
    const key = `${this.PREFIX_REACT}${memoryId}`;
    await this.ensureReactionsLoaded(memoryId);
    const val = await this.client.eval(
      `local v = redis.call('HINCRBY', KEYS[1], ARGV[1], -1)
       if v < 0 then
         redis.call('HSET', KEYS[1], ARGV[1], 0)
         return 0
       end
       return v`,
      1,
      key,
      emoji,
    ) as number;
    return val;
  }

  /** Fetch all emoji → count pairs for a memory. */
  async getReactions(memoryId: string): Promise<Record<string, number>> {
    const key = `${this.PREFIX_REACT}${memoryId}`;
    await this.ensureReactionsLoaded(memoryId);
    const raw = await this.client.hgetall(key);

    const result: Record<string, number> = {};
    for (const [emoji, val] of Object.entries(raw)) {
      if (emoji === '_loaded') continue;
      result[emoji] = parseInt(val ?? '0', 10);
    }
    return result;
  }

  /** Remove all reaction counts for a deleted memory. */
  async clearReactions(memoryId: string): Promise<void> {
    const key = `${this.PREFIX_REACT}${memoryId}`;
    await Promise.all([
      this.client.del(key),
      this.prisma.reaction.deleteMany({ where: { memoryId } }),
    ]);
  }

  /** Helper to load reaction counts from PostgreSQL if not present in Redis */
  private async ensureReactionsLoaded(memoryId: string): Promise<void> {
    const key = `${this.PREFIX_REACT}${memoryId}`;
    const exists = await this.client.exists(key);
    if (exists === 0) {
      // Load from DB
      const dbReactions = await this.prisma.reaction.findMany({
        where: { memoryId },
      });

      if (dbReactions.length > 0) {
        const pipeline = this.client.pipeline();
        for (const r of dbReactions) {
          pipeline.hset(key, r.emoji, r.count);
        }
        pipeline.hset(key, '_loaded', '1');
        // Set a TTL so inactive memories aren't cached in Redis forever
        pipeline.expire(key, 60 * 60 * 24 * 7); // 7 days
        await pipeline.exec();
      } else {
        // If not in DB, set a loaded flag with short TTL so we don't spam DB checks
        await this.client.hset(key, '_loaded', '1');
        await this.client.expire(key, 60 * 60 * 24); // 24 hours
      }
    }
  }

  /** Periodically flushes reactions to DB */
  async flushReactionsToDb(): Promise<void> {
    this.logger.log(`[Reactions Sync] Starting periodic sync from Redis to PostgreSQL...`);
    const startTime = Date.now();

    const keys = await this.getReactionKeys();
    if (keys.length === 0) {
      this.logger.log(`[Reactions Sync] No reaction keys found in Redis.`);
      return;
    }

    this.logger.log(`[Reactions Sync] Found ${keys.length} reaction keys. Syncing to DB...`);

    for (const key of keys) {
      const memoryId = key.replace(this.PREFIX_REACT, '');
      
      try {
        // Verify memory exists to avoid FK constraint error
        const memoryExists = await this.prisma.memory.findUnique({
          where: { id: memoryId },
          select: { id: true },
        });
        if (!memoryExists) {
          await this.client.del(key);
          continue;
        }

        const raw = await this.client.hgetall(key);
        for (const [emoji, val] of Object.entries(raw)) {
          if (emoji === '_loaded') continue;
          const count = parseInt(val ?? '0', 10);

          await this.prisma.reaction.upsert({
            where: {
              unique_memory_emoji: {
                memoryId,
                emoji,
              },
            },
            update: { count },
            create: {
              memoryId,
              emoji,
              count,
            },
          });
        }
      } catch (err) {
        this.logger.error(`[Reactions Sync] Failed to sync reactions for memoryId="${memoryId}": ${err.message}`);
      }
    }

    const duration = Date.now() - startTime;
    this.logger.log(`[Reactions Sync] Sync completed in ${duration}ms.`);
  }

  private async getReactionKeys(): Promise<string[]> {
    const stream = this.client.scanStream({
      match: `${this.PREFIX_REACT}*`,
      count: 100,
    });

    const keys = new Set<string>();

    return new Promise<string[]>((resolve, reject) => {
      stream.on('data', (chunk: string[]) => {
        for (const k of chunk) {
          keys.add(k);
        }
      });
      stream.on('end', () => resolve(Array.from(keys)));
      stream.on('error', (err) => reject(err));
    });
  }

  // ─── Refresh token allowlist ───────────────────────────────────────────────
  //
  // Each user has a Redis SET keyed `rt:<userId>` containing the JTIs (JWT IDs)
  // of all currently-valid refresh tokens.  On /auth/refresh the incoming JTI
  // is validated against this SET before a new pair is issued; the old JTI is
  // removed and the new one is added (token rotation).  On /auth/logout the
  // single JTI (or the whole SET for "logout everywhere") is deleted.

  /**
   * Add a refresh token JTI to the user's active-token allowlist.
   * The SET TTL is refreshed to 30 days on every write so idle accounts
   * are automatically evicted from Redis.
   */
  async storeRefreshToken(userId: string, jti: string): Promise<void> {
    const key = `${this.PREFIX_RT}${userId}`;
    await this.client
      .pipeline()
      .sadd(key, jti)
      .expire(key, REFRESH_TOKEN_TTL_SECONDS)
      .exec();
  }

  async storeRefreshSession(
    userId: string,
    jti: string,
    metadata: Record<string, unknown>,
  ): Promise<void> {
    const key = `${this.PREFIX_RTMETA}${userId}:${jti}`;
    await this.client
      .pipeline()
      .set(key, JSON.stringify({ ...metadata, userId, jti }), 'EX', REFRESH_TOKEN_TTL_SECONDS)
      .sadd(`${this.PREFIX_RT}${userId}`, jti)
      .expire(`${this.PREFIX_RT}${userId}`, REFRESH_TOKEN_TTL_SECONDS)
      .exec();
  }

  async listRefreshSessions(userId: string): Promise<Array<Record<string, unknown>>> {
    const jtis = await this.client.smembers(`${this.PREFIX_RT}${userId}`);
    if (jtis.length === 0) return [];

    const pipeline = this.client.pipeline();
    for (const jti of jtis) {
      pipeline.get(`${this.PREFIX_RTMETA}${userId}:${jti}`);
    }
    const results = await pipeline.exec();

    if (!results) return [];

    return results
      .map((entry) => entry?.[1])
      .filter(Boolean)
      .map((raw) => {
        try {
          return JSON.parse(raw as string) as Record<string, unknown>;
        } catch {
          return {};
        }
      });
  }

  /**
   * Returns true if the JTI is present in the user's allowlist
   * (i.e. the refresh token is still valid and not yet revoked).
   */
  async validateRefreshToken(userId: string, jti: string): Promise<boolean> {
    const isMember = await this.client.sismember(`${this.PREFIX_RT}${userId}`, jti);
    return isMember === 1;
  }

  /**
   * Remove a single JTI from the allowlist (single-device logout / token rotation).
   */
  async revokeRefreshToken(userId: string, jti: string): Promise<void> {
    await this.client
      .pipeline()
      .srem(`${this.PREFIX_RT}${userId}`, jti)
      .del(`${this.PREFIX_RTMETA}${userId}:${jti}`)
      .exec();
  }

  /**
   * Delete the entire allowlist SET for a user (logout everywhere / account lock).
   */
  async revokeAllUserTokens(userId: string): Promise<void> {
    const jtis = await this.client.smembers(`${this.PREFIX_RT}${userId}`);
    const pipeline = this.client.pipeline();
    pipeline.del(`${this.PREFIX_RT}${userId}`);
    for (const jti of jtis) {
      pipeline.del(`${this.PREFIX_RTMETA}${userId}:${jti}`);
    }
    await pipeline.exec();
  }

  // ─── One-time WebSocket upgrade tickets ───────────────────────────────────────
  //
  // Flow:
  //  1. Authenticated client calls POST /auth/ws-ticket (JwtAuthGuard).
  //  2. Server generates a cryptographically random 32-byte hex ticket,
  //     stores `ws:ticket:<ticket>` = JSON{userId,username} with 30s TTL.
  //  3. Client opens ws://.../ws?ticket=<ticket>.
  //  4. Gateway reads ?ticket=, calls redeemWsTicket (GET+DEL in a pipeline).
  //     - If found  → parse payload, attach userId/username to socket, continue.
  //     - If missing → ticket expired / already used / forged → terminate.
  //
  // The ticket never touches a JWT header, is single-use, and expires in 30s
  // so replay attacks after successful connection are impossible.

  /** Issue a 30-second single-use opaque ticket for WS upgrade. */
  async issueWsTicket(
    userId: string,
    username: string,
    ticket: string,
  ): Promise<void> {
    const key = `${this.PREFIX_TICKET}${ticket}`;
    const value = JSON.stringify({ userId, username });
    // SETEX: atomic set + 30-second expiry
    await this.client.setex(key, 30, value);
  }

  /**
   * Redeem (consume) a ticket.  Atomically GETs and DELetes the key so the
   * ticket is one-time-use even under concurrent connection attempts.
   * Returns the stored payload or null if expired / not found.
   */
  async redeemWsTicket(
    ticket: string,
  ): Promise<{ userId: string; username: string } | null> {
    const key = `${this.PREFIX_TICKET}${ticket}`;

    // Lua script: atomic GETDEL (available natively in Redis 6.2+;
    // the script provides the same guarantee on older versions).
    const raw = await this.client.eval(
      `local v = redis.call('GET', KEYS[1])
       if v then redis.call('DEL', KEYS[1]) end
       return v`,
      1,
      key,
    ) as string | null;

    if (!raw) return null;

    try {
      return JSON.parse(raw) as { userId: string; username: string };
    } catch {
      return null;
    }
  }

  // ─── Generic helpers ───────────────────────────────────────────────────────

  /** Expose the raw ioredis client for custom operations. */
  getClient(): Redis {
    return this.client;
  }
}
