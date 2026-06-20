import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class MessagesService {
  private readonly logger = new Logger(MessagesService.name);

  constructor(private readonly prisma: PrismaService) {}

  /** Persist a chat message. Called by the WebSocket gateway. */
  async create(data: { senderId: string; receiverId: string; text: string }) {
    this.logger.log(`[Messages DB] Persisting new message from senderId="${data.senderId}" to receiverId="${data.receiverId}"`);
    const message = await this.prisma.message.create({
      data,
      include: {
        sender:   { select: { id: true, username: true, avatarUrl: true } },
        receiver: { select: { id: true, username: true, avatarUrl: true } },
      },
    });
    this.logger.log(`[Messages DB] Message persisted successfully with id="${message.id}"`);
    return message;
  }

  /**
   * Paginated conversation thread between two users.
   * REST endpoint for loading older history when opening a chat window.
   */
  async getConversation(
    userAId: string,
    userBId: string,
    page = 1,
    limit = 50,
  ) {
    const skip = (page - 1) * limit;
    const [messages, total] = await Promise.all([
      this.prisma.message.findMany({
        where: {
          OR: [
            { senderId: userAId, receiverId: userBId },
            { senderId: userBId, receiverId: userAId },
          ],
        },
        orderBy: { timestamp: 'desc' },
        skip,
        take: limit,
        include: {
          sender:   { select: { id: true, username: true, avatarUrl: true } },
          receiver: { select: { id: true, username: true, avatarUrl: true } },
        },
      }),
      this.prisma.message.count({
        where: {
          OR: [
            { senderId: userAId, receiverId: userBId },
            { senderId: userBId, receiverId: userAId },
          ],
        },
      }),
    ]);

    return {
      data: messages.reverse(), // chronological order for UI
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  /** Mark all messages from a sender to the current user as read. */
  async markRead(receiverId: string, senderId: string) {
    this.logger.log(`[Messages DB] Marking messages as read: receiverId="${receiverId}" senderId="${senderId}"`);
    const result = await this.prisma.message.updateMany({
      where: { receiverId, senderId, isRead: false },
      data: { isRead: true },
    });
    this.logger.log(`[Messages DB] Marked ${result.count} messages as read`);
    return result;
  }
}
