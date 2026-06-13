import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AppGateway } from '../gateway/app.gateway';

@Injectable()
export class MemoriesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly gateway: AppGateway,
  ) {}

  /**
   * Paginated feed of memories posted by users inside the caller's circle.
   * Sorted newest-first using the idx_memories_creator_created composite index.
   */
  async getFeed(userId: string, page = 1, limit = 20) {
    const skip = (page - 1) * limit;

    // Fetch the IDs of all circle members the current user follows
    const memberships = await this.prisma.circleMembership.findMany({
      where: { userId, accepted: true },
      select: { memberId: true },
    });

    const memberIds = memberships.map((m) => m.memberId);

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
    const memory = await this.prisma.memory.create({
      data: { creatorId, ...data },
      include: {
        creator: {
          select: { id: true, username: true, firstName: true, avatarUrl: true },
        },
      },
    });

    // Notify circle members who have accepted and have this creator in their circle
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
    } catch (err) {
      // Safe fallback - don't crash memory creation if notifications fail
    }

    return memory;
  }
}
