import {
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { errorMessage } from '../common/errors';
import {
  buildNotificationContent,
  NotificationContent,
} from './notification-content';

/** Shape consumed by the client's `NotificationItem.fromJson`. */
export interface NotificationDto {
  id: string;
  title: string;
  body: string;
  timestamp: string;
  isRead: boolean;
  type: string;
  data: Record<string, string>;
}

const MAX_PAGE_SIZE = 50;
const DEFAULT_PAGE_SIZE = 20;

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Persist a notification for [userId] from a realtime event.
   *
   * Called on every dispatch — whether the user was online (delivered over the
   * WebSocket) or offline (delivered by FCM) — so the history screen shows the
   * same set of events either way. Never throws: a failed history write must
   * not break message or reaction delivery.
   */
  async record(
    userId: string,
    event: string,
    payload: Record<string, unknown>,
  ): Promise<void> {
    try {
      const content: NotificationContent = buildNotificationContent(
        event,
        payload,
      );
      await this.prisma.notification.create({
        data: {
          userId,
          type: content.type,
          title: content.title,
          body: content.body,
          data: JSON.stringify(content.data),
        },
      });
    } catch (err) {
      this.logger.error(
        `[Notifications] Failed to record event="${event}" for userId="${userId}": ${errorMessage(err)}`,
      );
    }
  }

  /**
   * Newest-first page of the caller's notifications.
   *
   * [cursor] is the ISO `createdAt` of the last item on the previous page,
   * matching the cursor convention used by the memories feed.
   */
  async list(userId: string, cursor?: string, limit = DEFAULT_PAGE_SIZE) {
    const take = Math.min(Math.max(limit, 1), MAX_PAGE_SIZE);

    const where: { userId: string; createdAt?: { lt: Date } } = { userId };
    if (cursor) {
      const cursorDate = new Date(cursor);
      if (!Number.isNaN(cursorDate.getTime())) {
        where.createdAt = { lt: cursorDate };
      }
    }

    const [rows, unreadCount] = await Promise.all([
      this.prisma.notification.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take: take + 1,
      }),
      this.prisma.notification.count({ where: { userId, isRead: false } }),
    ]);

    const hasNextPage = rows.length > take;
    const page = hasNextPage ? rows.slice(0, take) : rows;
    const nextCursor =
      hasNextPage && page.length > 0
        ? page[page.length - 1].createdAt.toISOString()
        : null;

    return {
      data: page.map((row) => this.toDto(row)),
      nextCursor,
      unreadCount,
    };
  }

  /** Mark one notification read. Only its owner may do so. */
  async markRead(userId: string, notificationId: string) {
    const existing = await this.prisma.notification.findUnique({
      where: { id: notificationId },
      select: { id: true, userId: true },
    });
    if (!existing) throw new NotFoundException('Notification not found');
    if (existing.userId !== userId) {
      throw new ForbiddenException('That notification is not yours');
    }

    await this.prisma.notification.update({
      where: { id: notificationId },
      data: { isRead: true },
    });
    return { id: notificationId, isRead: true };
  }

  /** Mark every unread notification for the caller as read. */
  async markAllRead(userId: string) {
    const result = await this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true },
    });
    return { updated: result.count };
  }

  private toDto(row: {
    id: string;
    title: string;
    body: string;
    createdAt: Date;
    isRead: boolean;
    type: string;
    data: string;
  }): NotificationDto {
    return {
      id: row.id,
      title: row.title,
      body: row.body,
      timestamp: row.createdAt.toISOString(),
      isRead: row.isRead,
      type: row.type,
      data: this.parseData(row.data),
    };
  }

  /** `data` is written by us as JSON, but a bad row must not fail the page. */
  private parseData(raw: string): Record<string, string> {
    try {
      const parsed: unknown = JSON.parse(raw || '{}');
      if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
        return {};
      }
      const out: Record<string, string> = {};
      for (const [k, v] of Object.entries(parsed as Record<string, unknown>)) {
        out[k] = typeof v === 'string' ? v : String(v);
      }
      return out;
    } catch {
      return {};
    }
  }
}
