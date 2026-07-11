import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import sanitizeHtml from 'sanitize-html';
import { PrismaService } from '../prisma/prisma.service';

const MAX_PAGE_SIZE = 50;
const DEFAULT_PAGE_SIZE = 10;

/** Shape consumed by the client's CommentRepository. */
export interface CommentDto {
  id: string;
  person: string;
  text: string;
  created_at: string;
  creator: {
    id: string;
    username: string;
    avatar_url: string | null;
  };
}

type CommentRow = {
  id: string;
  text: string;
  createdAt: Date;
  author: {
    id: string;
    username: string;
    firstName: string;
    avatarUrl: string | null;
  };
};

@Injectable()
export class CommentsService {
  private readonly logger = new Logger(CommentsService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Assert [userId] is allowed to see [memoryId] — they created it, or its
   * creator is an accepted member of their circle. Mirrors the rule enforced
   * by `GET /memories/:id`, so commenting cannot reach a memory the feed
   * would never show.
   *
   * A memory that does not exist and one the caller cannot see are reported
   * identically, so this cannot be used to probe for existence.
   */
  private async assertCanView(memoryId: string, userId: string) {
    const memory = await this.prisma.memory.findUnique({
      where: { id: memoryId },
      select: { id: true, creatorId: true, caption: true },
    });
    if (!memory) throw new NotFoundException('Memory not found');
    if (memory.creatorId === userId) return memory;

    const membership = await this.prisma.circleMembership.findUnique({
      where: {
        unique_user_member: { userId, memberId: memory.creatorId },
      },
    });
    if (!membership || !membership.accepted) {
      throw new NotFoundException('Memory not found');
    }
    return memory;
  }

  /**
   * Newest-first page of comments on a memory.
   * [cursor] is the ISO `createdAt` of the last item on the previous page.
   */
  async list(
    memoryId: string,
    userId: string,
    cursor?: string,
    limit = DEFAULT_PAGE_SIZE,
  ) {
    await this.assertCanView(memoryId, userId);

    const take = Math.min(Math.max(limit, 1), MAX_PAGE_SIZE);

    const where: { memoryId: string; createdAt?: { lt: Date } } = { memoryId };
    if (cursor) {
      const cursorDate = new Date(cursor);
      if (!Number.isNaN(cursorDate.getTime())) {
        where.createdAt = { lt: cursorDate };
      }
    }

    const rows = await this.prisma.comment.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: take + 1,
      include: {
        author: {
          select: {
            id: true,
            username: true,
            firstName: true,
            avatarUrl: true,
          },
        },
      },
    });

    const hasNextPage = rows.length > take;
    const page = hasNextPage ? rows.slice(0, take) : rows;
    const nextCursor =
      hasNextPage && page.length > 0
        ? page[page.length - 1].createdAt.toISOString()
        : null;

    return {
      comments: page.map((row) => CommentsService.toDto(row)),
      meta: { nextCursor, limit: take },
    };
  }

  /** Post a comment. The caller must be able to see the memory. */
  async create(memoryId: string, userId: string, text: string) {
    await this.assertCanView(memoryId, userId);

    // Strip all HTML to prevent stored XSS, exactly as memory captions are.
    const sanitized = sanitizeHtml(text, {
      allowedTags: [],
      allowedAttributes: {},
    }).trim();

    if (sanitized.length === 0) {
      throw new BadRequestException('Comment cannot be empty');
    }

    const row = await this.prisma.comment.create({
      data: { memoryId, authorId: userId, text: sanitized },
      include: {
        author: {
          select: {
            id: true,
            username: true,
            firstName: true,
            avatarUrl: true,
          },
        },
      },
    });

    this.logger.log(
      `[Comments] userId="${userId}" commented on memoryId="${memoryId}"`,
    );
    return CommentsService.toDto(row);
  }

  private static toDto(row: CommentRow): CommentDto {
    return {
      id: row.id,
      person: row.author.firstName || row.author.username,
      text: row.text,
      created_at: row.createdAt.toISOString(),
      creator: {
        id: row.author.id,
        username: row.author.username,
        avatar_url: row.author.avatarUrl ?? null,
      },
    };
  }
}
