import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { NotificationsService } from './notifications.service';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  // ─── GET /notifications?cursor=<iso>&limit=20 ────────────────────────────
  // Returns: { data: [...], nextCursor: string | null, unreadCount: number }

  @Get()
  async list(
    @Req() req: AuthenticatedRequest,
    @Query('cursor') cursor?: string,
    @Query('limit') limit = '20',
  ) {
    return this.notifications.list(
      req.user.id,
      cursor,
      parseInt(limit, 10) || 20,
    );
  }

  // ─── POST /notifications/read-all ────────────────────────────────────────
  // Declared before ':id/read' so 'read-all' is never captured as an :id.

  @Post('read-all')
  @HttpCode(HttpStatus.OK)
  async markAllRead(@Req() req: AuthenticatedRequest) {
    return this.notifications.markAllRead(req.user.id);
  }

  // ─── POST /notifications/:id/read ────────────────────────────────────────

  @Post(':id/read')
  @HttpCode(HttpStatus.OK)
  async markRead(@Req() req: AuthenticatedRequest, @Param('id') id: string) {
    return this.notifications.markRead(req.user.id, id);
  }
}
