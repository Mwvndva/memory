import {
  Injectable,
  ConflictException,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class CirclesService {
  constructor(private readonly prisma: PrismaService) {}

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
      where: { userId },
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
      where: { memberId: userId },
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
}
