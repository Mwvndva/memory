import {
  Injectable,
  ConflictException,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AppGateway } from '../gateway/app.gateway';

@Injectable()
export class CirclesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly gateway: AppGateway,
  ) {}

  // ─── Send a friend request (creates pending membership) ─────────────────

  /**
   * POST /circles/requests
   * Creates a CircleMembership with accepted=false (pending) and notifies
   * the target user via WebSocket so their inbox updates in real time.
   */
  async sendRequest(userId: string, memberId: string) {
    if (userId === memberId) {
      throw new BadRequestException('You cannot send a request to yourself');
    }

    // Ensure the target user exists
    const target = await this.prisma.user.findUnique({ where: { id: memberId } });
    if (!target) throw new NotFoundException('User not found');

    // Check if a membership (pending or accepted) already exists
    const existing = await this.prisma.circleMembership.findUnique({
      where: { unique_user_member: { userId, memberId } },
    });
    if (existing) {
      if (existing.accepted) {
        throw new ConflictException('This user is already in your circle');
      }
      throw new ConflictException('A pending request to this user already exists');
    }

    const sender = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, username: true, firstName: true, avatarUrl: true },
    });

    const membership = await this.prisma.circleMembership.create({
      data: { userId, memberId, accepted: false },
      include: {
        member: { select: { id: true, username: true, firstName: true, avatarUrl: true } },
      },
    });

    // Notify the receiver in real time (so their pending-requests badge updates)
    this.gateway.sendToUser(memberId, 'new_circle_request', {
      senderId: userId,
      senderUsername: sender?.username ?? '',
      senderFirstName: sender?.firstName ?? '',
      senderAvatarUrl: sender?.avatarUrl ?? null,
    });

    return { message: 'Circle request sent', membership };
  }

  // ─── Add member (directed friendship) ─────────────────────────────────────

  async addMember(userId: string, memberId: string) {
    if (userId === memberId) {
      throw new BadRequestException('You cannot add yourself to your circle');
    }

    // Ensure the target user exists
    const target = await this.prisma.user.findUnique({ where: { id: memberId } });
    if (!target) throw new NotFoundException('User to add was not found');

    // Upsert — idempotent if called twice
    try {
      return await this.prisma.circleMembership.create({
        data: { userId, memberId },
        include: {
          member: {
            select: { id: true, username: true, firstName: true, avatarUrl: true },
          },
        },
      });
    } catch (err: any) {
      // P2002 = unique constraint violation (already in circle)
      if (err?.code === 'P2002') {
        throw new ConflictException('This user is already in your circle');
      }
      throw err;
    }
  }

  // ─── Remove member ─────────────────────────────────────────────────────────

  async removeMember(userId: string, memberId: string) {
    const membership = await this.prisma.circleMembership.findFirst({
      where: { userId, memberId },
    });
    if (!membership) throw new NotFoundException('Membership not found');

    await this.prisma.circleMembership.delete({ where: { id: membership.id } });
    return { message: 'Member removed from your circle' };
  }

  // ─── List circle members ───────────────────────────────────────────────────

  async getCircle(userId: string) {
    const memberships = await this.prisma.circleMembership.findMany({
      where: { userId, accepted: true },
      orderBy: { createdAt: 'desc' },
      include: {
        member: {
          select: {
            id: true, username: true, firstName: true, lastName: true, avatarUrl: true,
          },
        },
      },
    });
    return memberships.map((m) => m.member);
  }

  // ─── List users who added the caller (reverse circle) ─────────────────────

  async getFollowers(userId: string) {
    const memberships = await this.prisma.circleMembership.findMany({
      where: { memberId: userId, accepted: true },
      orderBy: { createdAt: 'desc' },
      include: {
        user: {
          select: {
            id: true, username: true, firstName: true, lastName: true, avatarUrl: true,
          },
        },
      },
    });
    return memberships.map((m) => m.user);
  }

  // ─── List pending requests sent to the caller ──────────────────────────────

  async getPendingRequests(userId: string) {
    return this.prisma.circleMembership.findMany({
      where: { memberId: userId, accepted: false },
      orderBy: { createdAt: 'desc' },
      include: {
        user: {
          select: {
            id: true, username: true, firstName: true, lastName: true, avatarUrl: true,
          },
        },
      },
    });
  }

  // ─── Accept a share memories request ───────────────────────────────────────

  async acceptRequest(memberId: string, senderId: string) {
    const membership = await this.prisma.circleMembership.findFirst({
      where: { userId: senderId, memberId, accepted: false },
    });
    if (!membership) throw new NotFoundException('Request not found');

    const updated = await this.prisma.circleMembership.update({
      where: { id: membership.id },
      data: { accepted: true },
    });

    // Check and trigger milestone broadcast for the circle owner (senderId)
    await this.checkAndBroadcastCircleMilestone(senderId);

    return updated;
  }

  // ─── Decline a share memories request ───────────────────────────────────────

  async declineRequest(memberId: string, senderId: string) {
    const membership = await this.prisma.circleMembership.findFirst({
      where: { userId: senderId, memberId, accepted: false },
    });
    if (!membership) throw new NotFoundException('Request not found');

    await this.prisma.circleMembership.delete({ where: { id: membership.id } });
    return { message: 'Request declined' };
  }

  // ─── Check and broadcast circle milestones ────────────────────────────────
  
  async checkAndBroadcastCircleMilestone(userId: string) {
    try {
      // Count accepted circle members for userId
      const count = await this.prisma.circleMembership.count({
        where: { userId, accepted: true }
      });

      if (count === 7 || count === 30) {
        // Find the circle owner details
        const owner = await this.prisma.user.findUnique({
          where: { id: userId },
          select: { id: true, username: true, firstName: true, lastName: true, avatarUrl: true }
        });
        if (!owner) return;

        // Find all circle members
        const members = await this.prisma.user.findMany({
          where: {
            memberMemberships: {
              some: { userId, accepted: true }
            }
          },
          select: {
            id: true,
            username: true,
            firstName: true,
            lastName: true,
            avatarUrl: true,
            memories: {
              select: { id: true }
            }
          }
        });

        // Query owner memories count
        const ownerMemoriesCount = await this.prisma.memory.count({ where: { creatorId: userId } });

        // Format members data (including memory counts)
        const membersData = [
          // Include owner
          {
            id: owner.id,
            username: owner.username,
            firstName: owner.firstName,
            lastName: owner.lastName,
            avatarUrl: owner.avatarUrl,
            memoryCount: ownerMemoriesCount
          },
          // Include other circle members
          ...members.map(m => ({
            id: m.id,
            username: m.username,
            firstName: m.firstName,
            lastName: m.lastName,
            avatarUrl: m.avatarUrl,
            memoryCount: m.memories.length
          }))
        ];

        // Broadcast to all members of the circle (including the owner userId)
        const allUserIds = [userId, ...members.map(m => m.id)];

        for (const id of allUserIds) {
          this.gateway.sendToUser(id, 'new_circle_milestone', {
            circleOwnerId: userId,
            circleOwnerUsername: owner.username,
            milestone: count,
            members: membersData
          });
        }
      }
    } catch (err) {
      // Fail silently to prevent crashing friendship accept flow
    }
  }
}
