import { Controller, Get, Param, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { MessagesService } from './messages.service';
import { PrismaService } from '../prisma/prisma.service';

@UseGuards(JwtAuthGuard)
@Controller('messages')
export class MessagesController {
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
  ) {
    // Check if the target user is in the caller's circle (and accepted)
    const isMember = await this.prisma.circleMembership.findUnique({
      where: {
        unique_user_member: {
          userId: req.user.id,
          memberId: userId,
        },
      },
    });

    if (!isMember || !isMember.accepted) {
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

    return this.messagesService.getConversation(
      req.user.id,
      userId,
      parseInt(page, 10),
      parseInt(limit, 10),
    );
  }
}
