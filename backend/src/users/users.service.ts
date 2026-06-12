import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

const USER_SELECT = {
  id: true,
  firstName: true,
  lastName: true,
  username: true,
  email: true,
  phone: true,
  avatarUrl: true,
  createdAt: true,
} as const;

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  // ─── Username availability ─────────────────────────────────────────────────

  async checkUsername(username: string): Promise<{ available: boolean }> {
    const existing = await this.prisma.user.findUnique({ where: { username } });
    return { available: !existing };
  }

  // ─── Profile retrieval ─────────────────────────────────────────────────────

  async getProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: USER_SELECT,
    });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  // ─── Profile update ────────────────────────────────────────────────────────

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    // Strip undefined fields so we don't accidentally null them in Prisma
    const data = Object.fromEntries(
      Object.entries(dto).filter(([, v]) => v !== undefined),
    );

    return this.prisma.user.update({
      where: { id: userId },
      data,
      select: USER_SELECT,
    });
  }

  // ─── Search by phone numbers (contact sync) ────────────────────────────────

  async findByPhones(phones: string[]): Promise<{ id: string; username: string; phone: string }[]> {
    return this.prisma.user.findMany({
      where: { phone: { in: phones } },
      select: { id: true, username: true, phone: true },
    });
  }
}
