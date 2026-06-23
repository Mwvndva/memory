import { Injectable, forwardRef, Inject, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AppGateway } from '../gateway/app.gateway';
import { UsersService } from '../users/users.service';
import sanitizeHtml from 'sanitize-html';
import { JobsService } from '../jobs/jobs.service';
import { RedisService } from '../redis/redis.service';

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
  async getFeed(userId: string, cursor?: string, limit = 20) {
    this.logger.log(`[Get Feed] Loading memory feed for userId="${userId}" (cursor=${cursor}, limit=${limit})`);

    // 1. Check Redis Cache
    const cacheKey = `feed:${userId}:${cursor || 'start'}:${limit}`;
    try {
      const cached = await this.redisService.getClient().get(cacheKey);
      if (cached) {
        this.logger.log(`[Get Feed] Cache hit for userId="${userId}"`);
        return JSON.parse(cached);
      }
    } catch (err) {
      this.logger.error(`[Get Feed] Redis cache read failed: ${err.message}`);
    }

    // 2. Fetch the IDs of all circle members the current user follows
    const memberships = await this.prisma.circleMembership.findMany({
      where: { userId, accepted: true },
      select: { memberId: true },
    });

    const memberIds = memberships.map((m) => m.memberId);
    this.logger.log(`[Get Feed] Found ${memberIds.length} circle members for userId="${userId}"`);

    // Include the user's own memories in the feed as well
    const creatorIds = [userId, ...memberIds];

    // 3. Build Prisma where clause
    const whereClause: any = {
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
          select: { id: true, username: true, firstName: true, avatarUrl: true },
        },
      },
    });

    const hasNextPage = memories.length > limit;
    const data = hasNextPage ? memories.slice(0, limit) : memories;

    const nextCursor = hasNextPage && data.length > 0
      ? data[data.length - 1].createdAt.toISOString()
      : null;

    const result = {
      data,
      meta: {
        nextCursor,
        limit,
      },
    };

    // 5. Cache result in Redis for 30s
    try {
      await this.redisService.getClient().setex(cacheKey, 30, JSON.stringify(result));
    } catch (err) {
      this.logger.error(`[Get Feed] Redis cache write failed: ${err.message}`);
    }

    this.logger.log(`[Get Feed] Successfully loaded ${data.length} memories for userId="${userId}"`);
    return result;
  }

  /**
   * Retrieve a single memory by ID (archival retrieval).
   */
  async getById(memoryId: string) {
    return this.prisma.memory.findUnique({
      where: { id: memoryId },
      include: {
        creator: {
          select: { id: true, username: true, firstName: true, avatarUrl: true },
        },
      },
    });
  }

  /**
   * Create a new memory record (metadata only — video URL comes from storage).
   */
  async create(
    creatorId: string,
    data: { caption: string; videoUrl: string; gradientColors: string[] },
  ) {
    this.logger.log(`[Create Memory] Request by creatorId="${creatorId}"`);
    this.logger.log(`[Create Memory] Step 1: Saving memory metadata to database`);

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
          select: { id: true, username: true, firstName: true, avatarUrl: true },
        },
      },
    });

    // Notify circle members who have accepted and have this creator in their circle
    this.logger.log(`[Create Memory] Step 2: Queueing 'new_memory' notifications for circle members`);
    try {
      const memberships = await this.prisma.circleMembership.findMany({
        where: { memberId: creatorId, accepted: true },
        select: { userId: true },
      });
      
      const creatorName = memory.creator?.firstName || memory.creator?.username || 'A friend';
      for (const m of memberships) {
        await this.jobsService.queueNotification(m.userId, 'new_memory', {
          creatorName,
        });
      }
      this.logger.log(`[Create Memory] Queued websocket notifications for ${memberships.length} circle members`);
    } catch (err) {
      this.logger.error(`[Create Memory] Queueing WebSocket notification failed: ${err?.message ?? err}`);
    }

    // Update the creator's streak and ranking (via background queue)
    this.logger.log(`[Create Memory] Step 3: Queueing user stats/milestone recalculation for creatorId="${creatorId}"`);
    await this.jobsService.queueStatsRecalculation(creatorId);

    this.logger.log(`[Create Memory] Memory created successfully: id="${memory.id}"`);
    return memory;
  }
}
