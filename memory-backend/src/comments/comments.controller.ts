import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CommentsService } from './comments.service';
import { CreateCommentDto } from './dto/create-comment.dto';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

@UseGuards(JwtAuthGuard)
@Controller('memories/:memoryId/comments')
export class CommentsController {
  constructor(private readonly comments: CommentsService) {}

  // ─── GET /memories/:memoryId/comments?cursor=<iso>&limit=10 ──────────────
  // Returns: { comments: [...], meta: { nextCursor, limit } }

  @Get()
  async list(
    @Req() req: AuthenticatedRequest,
    @Param('memoryId') memoryId: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit = '10',
  ) {
    return this.comments.list(
      memoryId,
      req.user.id,
      cursor,
      parseInt(limit, 10) || 10,
    );
  }

  // ─── POST /memories/:memoryId/comments ───────────────────────────────────
  // Body: { text }   Returns: the created comment

  @Post()
  async create(
    @Req() req: AuthenticatedRequest,
    @Param('memoryId') memoryId: string,
    @Body() dto: CreateCommentDto,
  ) {
    return this.comments.create(memoryId, req.user.id, dto.text);
  }
}
