import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CirclesService } from './circles.service';
import { AddMemberDto } from './dto/add-member.dto';
import { AcceptDeclineRequestDto } from './dto/accept-decline-request.dto';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

@UseGuards(JwtAuthGuard)
@Controller('circles')
export class CirclesController {
  constructor(private readonly circlesService: CirclesService) {}

  /**
   * GET /circles/members
   * Authenticated — lists all users in the caller's circle (outgoing directed friendships).
   */
  @Get('members')
  getCircle(@Req() req: AuthenticatedRequest) {
    return this.circlesService.getCircle(req.user.id);
  }

  /**
   * GET /circles/followers
   * Authenticated — lists all users who have added the caller to their circle.
   */
  @Get('followers')
  getFollowers(@Req() req: AuthenticatedRequest) {
    return this.circlesService.getFollowers(req.user.id);
  }

  /**
   * POST /circles/requests
   * Authenticated — sends a circle (friend) request to a user by their UUID.
   * Creates a pending CircleMembership (accepted=false) and notifies the
   * receiver via WebSocket. This is the primary path used by the Flutter app.
   * Body: { "memberId": "<uuid>" }
   */
  @Post('requests')
  sendRequest(@Req() req: AuthenticatedRequest, @Body() dto: AddMemberDto) {
    return this.circlesService.sendRequest(req.user.id, dto.memberId);
  }

  /**
   * POST /circles/members
   * Authenticated — adds a user to the caller's circle by their UUID.
   * Body: { "memberId": "<uuid>" }
   */
  @Post('members')
  addMember(@Req() req: AuthenticatedRequest, @Body() dto: AddMemberDto) {
    return this.circlesService.addMember(req.user.id, dto.memberId);
  }

  /**
   * DELETE /circles/members/:memberId
   * Authenticated — removes a user from the caller's circle.
   */
  @Delete('members/:memberId')
  removeMember(
    @Req() req: AuthenticatedRequest,
    @Param('memberId') memberId: string,
  ) {
    return this.circlesService.removeMember(req.user.id, memberId);
  }

  /**
   * GET /circles/requests/pending
   * Authenticated — lists pending requests sent to the caller.
   */
  @Get('requests/pending')
  getPendingRequests(@Req() req: AuthenticatedRequest) {
    return this.circlesService.getPendingRequests(req.user.id);
  }

  /**
   * POST /circles/requests/accept
   * Authenticated — accepts a share memories request.
   */
  @Post('requests/accept')
  acceptRequest(
    @Req() req: AuthenticatedRequest,
    @Body() dto: AcceptDeclineRequestDto,
  ) {
    return this.circlesService.acceptRequest(req.user.id, dto.senderId);
  }

  /**
   * POST /circles/requests/decline
   * Authenticated — declines a share memories request.
   */
  @Post('requests/decline')
  declineRequest(
    @Req() req: AuthenticatedRequest,
    @Body() dto: AcceptDeclineRequestDto,
  ) {
    return this.circlesService.declineRequest(req.user.id, dto.senderId);
  }
}
