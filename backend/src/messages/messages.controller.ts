import { Controller, Get, Param, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { MessagesService } from './messages.service';

@UseGuards(JwtAuthGuard)
@Controller('messages')
export class MessagesController {
  constructor(private readonly messagesService: MessagesService) {}

  /**
   * GET /messages/history/:userId?page=1&limit=50
   * Authenticated — fetches paginated conversation history between the caller
   * and another user. Used by the Flutter app to load older messages on scroll.
   */
  @Get('history/:userId')
  getHistory(
    @Req() req: any,
    @Param('userId') userId: string,
    @Query('page') page = '1',
    @Query('limit') limit = '50',
  ) {
    return this.messagesService.getConversation(
      req.user.id,
      userId,
      parseInt(page, 10),
      parseInt(limit, 10),
    );
  }
}
