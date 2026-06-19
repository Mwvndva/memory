import { Injectable, OnModuleDestroy, OnModuleInit, Logger } from '@nestjs/common';
import Redis from 'ioredis';

/**
 * Low-level Redis client wrapper.
 *
 * Responsibilities:
 *  - WebSocket session state  (userId ↔ socketId mapping)
 *  - Rate-limiting buckets    (sliding-window counters per user/IP)
 *  - Emoji reaction counts    (fast atomic increments per memory)
 */
@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private client: Redis;

  // ─── Key prefixes ──────────────────────────────────────────────────────────
  private readonly PREFIX_SOCKET = 'ws:socket:';   // ws:socket:<userId>  → socketId
  private readonly PREFIX_USER   = 'ws:user:';     // ws:user:<socketId>  → userId
  private readonly PREFIX_RL     = 'rl:';          // rl:<userId|ip>      → hit count
  private readonly PREFIX_REACT  = 'react:';       // react:<memoryId>:<emoji> → count

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  onModuleInit() {
    this.client = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379', {
      maxRetriesPerRequest: 3,
      enableReadyCheck: true,
    });

    this.client.on('connect', () => this.logger.log('Redis connected'));
    this.client.on('error',   (err) => this.logger.error('Redis error', err));
  }

  async onModuleDestroy() {
    await this.client.quit();
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

  /** Return all currently connected user IDs (scans active ws:socket:* keys). */
  async getOnlineUserIds(): Promise<string[]> {
    const keys = await this.client.keys(`${this.PREFIX_SOCKET}*`);
    return keys.map((k) => k.replace(this.PREFIX_SOCKET, ''));
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

  /** Atomically increment an emoji reaction count for a memory. */
  async incrementReaction(memoryId: string, emoji: string): Promise<number> {
    const key = `${this.PREFIX_REACT}${memoryId}:${emoji}`;
    return this.client.incr(key);
  }

  /** Decrement (remove one reaction) — floors at 0. */
  async decrementReaction(memoryId: string, emoji: string): Promise<number> {
    const key = `${this.PREFIX_REACT}${memoryId}:${emoji}`;
    const val = await this.client.decr(key);
    if (val < 0) {
      await this.client.set(key, 0);
      return 0;
    }
    return val;
  }

  /** Fetch all emoji → count pairs for a memory. */
  async getReactions(memoryId: string): Promise<Record<string, number>> {
    const pattern = `${this.PREFIX_REACT}${memoryId}:*`;
    const keys = await this.client.keys(pattern);
    if (keys.length === 0) return {};

    const values = await this.client.mget(...keys);
    const result: Record<string, number> = {};
    keys.forEach((key, i) => {
      const emoji = key.replace(`${this.PREFIX_REACT}${memoryId}:`, '');
      result[emoji] = parseInt(values[i] ?? '0', 10);
    });
    return result;
  }

  /** Remove all reaction counts for a deleted memory. */
  async clearReactions(memoryId: string): Promise<void> {
    const keys = await this.client.keys(`${this.PREFIX_REACT}${memoryId}:*`);
    if (keys.length > 0) await this.client.del(...keys);
  }

  // ─── Generic helpers ───────────────────────────────────────────────────────

  /** Expose the raw ioredis client for custom operations. */
  getClient(): Redis {
    return this.client;
  }
}
