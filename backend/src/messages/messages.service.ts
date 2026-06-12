import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class MessagesService {
  constructor(private readonly prisma: PrismaService) {}

  /** Persist a chat message. Called by the WebSocket gateway. */
  async create(data: { senderId: string; receiverId: string; text: string }) {
    return this.prisma.message.create({
      data,
      include: {
        sender:   { select: { id: true, username: true, avatarUrl: true } },
        receiver: { select: { id: true, username: true, avatarUrl: true } },
      },
    });
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
    return this.prisma.message.updateMany({
      where: { receiverId, senderId, isRead: false },
      data: { isRead: true },
    });
  }
}
