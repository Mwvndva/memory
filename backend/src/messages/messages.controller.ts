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
   * GET /messages/history/:userId?page=1&limit=50
   * Authenticated — fetches paginated conversation history between the caller
   * and another user. Used by the Flutter app to load older messages on scroll.
   */
  @Get('history/:userId')
  async getHistory(
    @Req() req: any,
    @Param('userId') userId: string,
    @Query('page') page = '1',
    @Query('limit') limit = '50',
    @Query('markRead') markRead = 'true',
  ) {
    // Check if the target user is in the caller's circle (accepted) OR the
    // caller is in the target user's circle (accepted). This allows messaging
    // to work for either party after acceptance.
    const outgoing = await this.prisma.circleMembership.findUnique({
      where: { unique_user_member: { userId: req.user.id, memberId: userId } },
    });
    const incoming = await this.prisma.circleMembership.findUnique({
      where: { unique_user_member: { userId: userId, memberId: req.user.id } },
    });

    if (!((outgoing && outgoing.accepted) || (incoming && incoming.accepted))) {
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
    this.logger.log(`[Get History] Loading conversation: callerId="${req.user.id}" targetId="${userId}" markRead=${shouldMarkRead}`);

    return this.messagesService.getConversation(
      req.user.id,
      userId,
      parseInt(page, 10),
      parseInt(limit, 10),
    ).then(async (result) => {
      if (shouldMarkRead) {
        // Mark all messages from this sender to the current user as read
        // (fire-and-forget — don't await so response isn't delayed)
        this.logger.log(`[Get History] Marking messages as read for callerId="${req.user.id}" from senderId="${userId}"`);
        this.messagesService.markRead(req.user.id, userId).catch(() => {});
      } else {
        this.logger.log(`[Get History] Skipping markRead (background preview load) for callerId="${req.user.id}"`);
      }
      return result;
    });
  }
}
