import {
  Injectable,
  forwardRef,
  Inject,
  Logger,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AppGateway } from '../gateway/app.gateway';
import { UsersService } from '../users/users.service';
import sanitizeHtml from 'sanitize-html';
import { JobsService } from '../jobs/jobs.service';
import { RedisService } from '../redis/redis.service';
import { errorMessage } from '../common/errors';

export interface MemoryCreator {
  id: string;
  username: string;
  firstName: string;
  avatarUrl: string | null;
}

/**
 * A memory joined with its creator.
 *
 * `createdAt` is a `Date` when the row comes from Postgres and an ISO `string`
 * when it is served from the Redis cache — JSON has no date type. Consumers
 * must normalise it (`new Date(m.createdAt)`), which is why the union is
 * spelled out rather than hidden behind `any`.
 */
export interface MemoryWithCreator {
  id: string;
  creatorId: string;
  caption: string;
  videoUrl: string;
  gradientColors: string[];
  createdAt: Date | string;
  creator?: MemoryCreator | null;
}

export interface FeedPage {
  data: MemoryWithCreator[];
  meta: { nextCursor: string | null; limit: number };
}

@Injectable()
export class MemoriesService {
  private readonly logger = new Logger(MemoriesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly gateway: AppGateway,
    @Inject(forwardRef(() => UsersService))
    private readonly usersService: UsersService,
    private readonly jobsService: JobsService,
    private readonly redisService: RedisService,
  ) {}

  /**
   * Paginated feed of memories posted by users inside the caller's circle.
   * Sorted newest-first using the idx_memories_creator_created composite index.
   */
  async getFeed(
    userId: string,
    cursor?: string,
    limit = 20,
  ): Promise<FeedPage> {
    this.logger.log(
      `[Get Feed] Loading memory feed for userId="${userId}" (cursor=${cursor}, limit=${limit})`,
    );

    // 1. Check Redis Cache
    const cacheKey = `feed:${userId}:${cursor || 'start'}:${limit}`;
    try {
      const cached = await this.redisService.getClient().get(cacheKey);
      if (cached) {
        this.logger.log(`[Get Feed] Cache hit for userId="${userId}"`);
        return JSON.parse(cached) as FeedPage;
      }
    } catch (err) {
      this.logger.error(
        `[Get Feed] Redis cache read failed: ${errorMessage(err)}`,
      );
    }

    // 2. Fetch the IDs of all circle members the current user follows
    const memberships = await this.prisma.circleMembership.findMany({
      where: { userId, accepted: true },
      select: { memberId: true },
    });

    const memberIds = memberships.map((m) => m.memberId);
    this.logger.log(
      `[Get Feed] Found ${memberIds.length} circle members for userId="${userId}"`,
    );

    // Include the user's own memories in the feed as well
    const creatorIds = [userId, ...memberIds];

    // 3. Build Prisma where clause
    const whereClause: {
      creatorId: { in: string[] };
      createdAt?: { lt: Date };
    } = {
      creatorId: { in: creatorIds },
    };

    if (cursor) {
      whereClause.createdAt = {
        lt: new Date(cursor),
      };
    }

    // 4. Query memories (take limit + 1 to check for next page)
    const memories = await this.prisma.memory.findMany({
      where: whereClause,
      orderBy: { createdAt: 'desc' },
      take: limit + 1,
      include: {
        creator: {
          select: {
            id: true,
            username: true,
            firstName: true,
            avatarUrl: true,
          },
        },
      },
    });

    const hasNextPage = memories.length > limit;
    const data = hasNextPage ? memories.slice(0, limit) : memories;

    const nextCursor =
      hasNextPage && data.length > 0
        ? data[data.length - 1].createdAt.toISOString()
        : null;

    const result: FeedPage = {
      data,
      meta: {
        nextCursor,
        limit,
      },
    };

    // 5. Cache result in Redis for 30s
    try {
      await this.redisService
        .getClient()
        .setex(cacheKey, 30, JSON.stringify(result));
    } catch (err) {
      this.logger.error(
        `[Get Feed] Redis cache write failed: ${errorMessage(err)}`,
      );
    }

    this.logger.log(
      `[Get Feed] Successfully loaded ${data.length} memories for userId="${userId}"`,
    );
    return result;
  }

  /**
   * Retrieve a single memory by ID (archival retrieval).
   * Cached in Redis (30s). The per-caller circle-membership authorization
   * happens in MemoriesController.getMemory *after* this fetch, so caching the
   * raw record does not bypass any access check.
   */
  async getById(memoryId: string): Promise<MemoryWithCreator | null> {
    const cacheKey = `memory:${memoryId}`;
    const cached =
      await this.redisService.cacheGetJson<MemoryWithCreator>(cacheKey);
    if (cached) return cached;

    const memory = await this.prisma.memory.findUnique({
      where: { id: memoryId },
      include: {
        creator: {
          select: {
            id: true,
            username: true,
            firstName: true,
            avatarUrl: true,
          },
        },
      },
    });

    if (memory) {
      await this.redisService.cacheSetJson(cacheKey, memory, 30);
    }
    return memory;
  }

  /**
   * Create a new memory record (metadata only — video URL comes from storage).
   */
  async create(
    creatorId: string,
    data: { caption: string; videoUrl: string; gradientColors: string[] },
  ) {
    this.logger.log(`[Create Memory] Request by creatorId="${creatorId}"`);
    this.logger.log(
      `[Create Memory] Step 1: Saving memory metadata to database`,
    );

    // Sanitize caption to prevent stored XSS (strip all HTML tags)
    const sanitizedCaption = sanitizeHtml(data.caption, {
      allowedTags: [],
      allowedAttributes: {},
    });

    const memory = await this.prisma.memory.create({
      data: {
        creatorId,
        ...data,
        caption: sanitizedCaption,
      },
      include: {
        creator: {
          select: {
            id: true,
            username: true,
            firstName: true,
            avatarUrl: true,
          },
        },
      },
    });

    // Notify circle members who have accepted and have this creator in their circle
    this.logger.log(
      `[Create Memory] Step 2: Queueing 'new_memory' notifications for circle members`,
    );
    try {
      const memberships = await this.prisma.circleMembership.findMany({
        where: { memberId: creatorId, accepted: true },
        select: { userId: true },
      });

      const creatorName =
        memory.creator?.firstName || memory.creator?.username || 'A friend';
      for (const m of memberships) {
        await this.jobsService.queueNotification(m.userId, 'new_memory', {
          creatorName,
          creatorUsername: memory.creator?.username ?? '',
          memoryId: memory.id,
        });
      }
      this.logger.log(
        `[Create Memory] Queued websocket notifications for ${memberships.length} circle members`,
      );
    } catch (err) {
      this.logger.error(
        `[Create Memory] Queueing WebSocket notification failed: ${errorMessage(err)}`,
      );
    }

    // Update the creator's streak and ranking (via background queue)
    this.logger.log(
      `[Create Memory] Step 3: Queueing user stats/milestone recalculation for creatorId="${creatorId}"`,
    );
    await this.jobsService.queueStatsRecalculation(creatorId);

    this.logger.log(
      `[Create Memory] Memory created successfully: id="${memory.id}"`,
    );
    return memory;
  }

  private static readonly CREATOR_SELECT = {
    creator: {
      select: {
        id: true,
        username: true,
        firstName: true,
        avatarUrl: true,
      },
    },
  };

  /**
   * Load a memory and assert [userId] owns it.
   * Throws rather than returning null so callers cannot forget the check.
   */
  private async assertOwned(memoryId: string, userId: string) {
    const memory = await this.prisma.memory.findUnique({
      where: { id: memoryId },
      select: { id: true, creatorId: true },
    });
    if (!memory) {
      throw new NotFoundException('Memory not found');
    }
    if (memory.creatorId !== userId) {
      throw new ForbiddenException('You can only modify your own memories');
    }
    return memory;
  }

  /**
   * Edit a memory's caption. Owner only.
   *
   * Feed pages are cached for 30s and are not invalidated here: they are keyed
   * per viewer/cursor, so a targeted purge would mean scanning. The single
   * memory cache — which the detail screen reads — is purged immediately.
   */
  async updateCaption(memoryId: string, userId: string, caption: string) {
    await this.assertOwned(memoryId, userId);

    const sanitizedCaption = sanitizeHtml(caption, {
      allowedTags: [],
      allowedAttributes: {},
    });

    const updated = await this.prisma.memory.update({
      where: { id: memoryId },
      data: { caption: sanitizedCaption },
      include: MemoriesService.CREATOR_SELECT,
    });

    await this.redisService.cacheDel(`memory:${memoryId}`);
    this.logger.log(`[Update Memory] Caption updated for id="${memoryId}"`);
    return updated;
  }

  /**
   * Soft-delete a memory (PrismaService rewrites delete → set deletedAt).
   * Owner only. Reaction counters are dropped from both Redis and Postgres.
   */
  async remove(memoryId: string, userId: string) {
    await this.assertOwned(memoryId, userId);

    await this.prisma.memory.delete({ where: { id: memoryId } });
    await this.redisService.clearReactions(memoryId);
    await this.redisService.cacheDel(`memory:${memoryId}`);

    this.logger.log(`[Delete Memory] Soft-deleted id="${memoryId}"`);
    return { id: memoryId, deleted: true };
  }
}
