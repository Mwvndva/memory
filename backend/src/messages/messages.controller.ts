import { Controller, Get, Param, Query, Req, UseGuards, Logger } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { MessagesService } from './messages.service';
import { PrismaService } from '../prisma/prisma.service';

@UseGuards(JwtAuthGuard)
@Controller('messages')
export class MessagesController {
  private readonly logger = new Logger(MessagesController.name);

  constructor(
    private readonly messagesService: MessagesService,
    private readonly prisma: PrismaService,
  ) {}

  /**
   * GET /messages/history/:conversationId
   * GET /messages/history/:userId
   * Authenticated — fetches paginated conversation history between the caller
   * and another user/conversation. Used by the Flutter app to load older messages on scroll.
   */
  @Get('history/:conversationId')
  async getHistory(
    @Req() req: any,
    @Param('conversationId') conversationId: string,
    @Query('page') page = '1',
    @Query('limit') limit = '50',
    @Query('markRead') markRead = 'true',
  ) {
    const callerId = req.user?.id;
    if (!callerId) {
      this.logger.error(`[Get History] Unauthenticated request context.`);
      return {
        data: [],
        meta: { page: 1, limit: 50, total: 0, totalPages: 0 }
      };
    }

    try {
      this.logger.log(`[Get History] Fetching relationship for callerId="${callerId}" with memberId/convId="${conversationId}"`);
      // Resolve either-direction membership details
      const outgoing = await this.prisma.circleMembership.findUnique({
        where: { unique_user_member: { userId: callerId, memberId: conversationId } },
      });
      const incoming = await this.prisma.circleMembership.findUnique({
        where: { unique_user_member: { userId: conversationId, memberId: callerId } },
      });

      if (!((outgoing && outgoing.accepted) || (incoming && incoming.accepted))) {
        this.logger.warn(`[Get History] Request blocked: No active circle membership between caller="${callerId}" and target="${conversationId}"`);
        return {
          data: [],
          meta: {
            page: parseInt(page, 10),
            limit: parseInt(limit, 10),
            total: 0,
            totalPages: 0,
          },
        };
      }

      const shouldMarkRead = markRead !== 'false';
      this.logger.log(`[Get History] Loading conversation: callerId="${callerId}" targetId="${conversationId}" markRead=${shouldMarkRead}`);

      const result = await this.messagesService.getConversation(
        callerId,
        conversationId,
        parseInt(page, 10),
        parseInt(limit, 10),
      );

      if (shouldMarkRead) {
        this.logger.log(`[Get History] Marking messages as read for callerId="${callerId}" from senderId="${conversationId}"`);
        this.messagesService.markRead(callerId, conversationId).catch((err) => {
          this.logger.error(`[Get History] Failed to mark messages as read: ${err.message}`, err.stack);
        });
      } else {
        this.logger.log(`[Get History] Skipping markRead (background preview load) for callerId="${callerId}"`);
      }
      return result;
    } catch (err: any) {
      this.logger.error(`[Get History] Exception caught during loading: ${err.message}`, err.stack);
      return {
        data: [],
        meta: {
          page: parseInt(page, 10),
          limit: parseInt(limit, 10),
          total: 0,
          totalPages: 0,
        },
      };
    }
  }
}
