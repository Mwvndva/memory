import { Injectable, forwardRef, Inject, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AppGateway } from '../gateway/app.gateway';
import { UsersService } from '../users/users.service';
import sanitizeHtml from 'sanitize-html';

@Injectable()
export class MemoriesService {
  private readonly logger = new Logger(MemoriesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly gateway: AppGateway,
    @Inject(forwardRef(() => UsersService))
    private readonly usersService: UsersService,
  ) {}

  /**
   * Paginated feed of memories posted by users inside the caller's circle.
   * Sorted newest-first using the idx_memories_creator_created composite index.
   */
  async getFeed(userId: string, page = 1, limit = 20) {
    this.logger.log(`[Get Feed] Loading memory feed for userId="${userId}" (page=${page}, limit=${limit})`);
    const skip = (page - 1) * limit;

    // Fetch the IDs of all circle members the current user follows
    const memberships = await this.prisma.circleMembership.findMany({
      where: { userId, accepted: true },
      select: { memberId: true },
    });

    const memberIds = memberships.map((m) => m.memberId);
    this.logger.log(`[Get Feed] Found ${memberIds.length} circle members for userId="${userId}"`);

    // Include the user's own memories in the feed as well
    const creatorIds = [userId, ...memberIds];

    const [memories, total] = await Promise.all([
      this.prisma.memory.findMany({
        where: { creatorId: { in: creatorIds } },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
        include: {
          creator: {
            select: { id: true, username: true, firstName: true, avatarUrl: true },
          },
        },
      }),
      this.prisma.memory.count({ where: { creatorId: { in: creatorIds } } }),
    ]);

    this.logger.log(`[Get Feed] Successfully loaded ${memories.length} memories (total=${total}) for userId="${userId}"`);
    return {
      data: memories,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
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
    this.logger.log(`[Create Memory] Step 2: Broadcasting 'new_memory' notifications to circle members`);
    try {
      const memberships = await this.prisma.circleMembership.findMany({
        where: { memberId: creatorId, accepted: true },
        select: { userId: true },
      });
      
      const creatorName = memory.creator?.firstName || memory.creator?.username || 'A friend';
      for (const m of memberships) {
        this.gateway.sendToUser(m.userId, 'new_memory', {
          creatorName,
        });
      }
      this.logger.log(`[Create Memory] Sent websocket notifications to ${memberships.length} circle members`);
    } catch (err) {
      this.logger.error(`[Create Memory] WebSocket notification failed: ${err?.message ?? err}`);
      // Safe fallback - don't crash memory creation if notifications fail
    }

    // Update the creator's streak and ranking (fire-and-forget — non-blocking)
    this.logger.log(`[Create Memory] Step 3: Triggering user stats/milestone recalculation for creatorId="${creatorId}"`);
    this.usersService.recalculateUserStats(creatorId).catch((err) => {
      this.logger.error(`[Create Memory] User stats recalculation failed for creatorId="${creatorId}": ${err?.message ?? err}`);
    });

    this.logger.log(`[Create Memory] Memory created successfully: id="${memory.id}"`);
    return memory;
  }
}
