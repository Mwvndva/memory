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
  country: true,
  streakDays: true,
  countryRank: true,
  globalRank: true,
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
    const stats = await this.getUserStats(userId);
    return {
      ...user,
      stats,
    };
  }

  // ─── Profile update ────────────────────────────────────────────────────────
  async updateProfile(userId: string, dto: UpdateProfileDto) {
    // Strip undefined fields so we don't accidentally null them in Prisma
    const data: any = Object.fromEntries(
      Object.entries(dto).filter(([, v]) => v !== undefined),
    );

    if (dto.phone) {
      data.country = dto.phone.split(' ')[0] || '🇰🇪';
    }

    const user = await this.prisma.user.update({
      where: { id: userId },
      data,
      select: USER_SELECT,
    });
    const stats = await this.getUserStats(userId);
    return {
      ...user,
      stats,
    };
  }

  // ─── Search by phone numbers (contact sync) ────────────────────────────────
  async findByPhones(phones: string[]): Promise<{ id: string; username: string; phone: string }[]> {
    return this.prisma.user.findMany({
      where: { phone: { in: phones } },
      select: { id: true, username: true, phone: true },
    });
  }

  // ─── Streak, Rank, and Pulse Stats Calculations ────────────────────────────
  async getUserStats(userId: string) {
    // 1. Fetch user's country flag from phone prefix
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { phone: true },
    });
    const phone = user?.phone || '';
    const flagEmoji = phone.split(' ')[0] || '🇰🇪';

    // 2. Fetch all users and their memories to compute streaks & ranks
    const allUsers = await this.prisma.user.findMany({
      include: {
        memories: {
          select: { createdAt: true },
          orderBy: { createdAt: 'desc' },
        },
      },
    });

    const userStreaks = allUsers.map((u) => {
      const streak = this.calculateUserStreak(u.memories);
      const country = u.phone.split(' ')[0] || '🇰🇪';
      return {
        userId: u.id,
        streak,
        country,
      };
    });

    // Sort globally by streak (descending)
    userStreaks.sort((a, b) => b.streak - a.streak);

    // Global ranks (equal streaks get same rank)
    let currentGlobalRank = 1;
    let prevGlobalStreak = -1;
    const globalRanksMap = new Map<string, number>();

    for (let i = 0; i < userStreaks.length; i++) {
      const u = userStreaks[i];
      if (u.streak !== prevGlobalStreak) {
        currentGlobalRank = i + 1;
        prevGlobalStreak = u.streak;
      }
      globalRanksMap.set(u.userId, currentGlobalRank);
    }

    // Country ranks
    const countryGroups = new Map<string, typeof userStreaks>();
    for (const u of userStreaks) {
      if (!countryGroups.has(u.country)) {
        countryGroups.set(u.country, []);
      }
      countryGroups.get(u.country)!.push(u);
    }

    const countryRanksMap = new Map<string, number>();
    for (const [country, group] of countryGroups.entries()) {
      group.sort((a, b) => b.streak - a.streak);
      let currentCountryRank = 1;
      let prevCountryStreak = -1;
      for (let i = 0; i < group.length; i++) {
        const u = group[i];
        if (u.streak !== prevCountryStreak) {
          currentCountryRank = i + 1;
          prevCountryStreak = u.streak;
        }
        countryRanksMap.set(u.userId, currentCountryRank);
      }
    }

    // 2.5 Save/Update country, streaks, and ranks in User table for all users
    for (const u of userStreaks) {
      const gRank = globalRanksMap.get(u.userId) ?? 1;
      const cRank = countryRanksMap.get(u.userId) ?? 1;
      await this.prisma.user.update({
        where: { id: u.userId },
        data: {
          country: u.country,
          streakDays: u.streak,
          countryRank: cRank,
          globalRank: gRank <= 300000 ? gRank : null,
        },
      });
    }

    const userStreak = userStreaks.find((us) => us.userId === userId)?.streak ?? 0;
    const rawGlobalRank = globalRanksMap.get(userId) ?? 1;
    const countryRank = countryRanksMap.get(userId) ?? 1;

    // Show global rank only if user is in top 300,000
    const globalRank = rawGlobalRank <= 300000 ? rawGlobalRank : null;

    // 3. Compute Circle Pulse (consecutive daily posts by anyone in circle)
    const circleMemberships = await this.prisma.circleMembership.findMany({
      where: { userId },
      select: { memberId: true },
    });
    const circleUserIds = [userId, ...circleMemberships.map((m) => m.memberId)];

    const circleMemories = await this.prisma.memory.findMany({
      where: { creatorId: { in: circleUserIds } },
      select: { createdAt: true },
      orderBy: { createdAt: 'desc' },
    });

    const circlePulseDays = this.calculateCirclePulse(circleMemories);

    return {
      streakDays: userStreak,
      circlePulseDays,
      countryRank,
      globalRank,
      flagEmoji,
    };
  }

  private calculateUserStreak(memories: { createdAt: Date }[]): number {
    if (memories.length === 0) return 0;

    // Extract unique UTC dates (YYYY-MM-DD)
    const uniqueDates = Array.from(
      new Set(
        memories.map((m) => {
          const d = new Date(m.createdAt);
          return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(d.getUTCDate()).padStart(2, '0')}`;
        })
      )
    ).sort((a, b) => b.localeCompare(a)); // Descending order (newest first)

    if (uniqueDates.length === 0) return 0;

    const todayStr = new Date().toISOString().split('T')[0];
    const yesterday = new Date();
    yesterday.setUTCDate(yesterday.getUTCDate() - 1);
    const yesterdayStr = yesterday.toISOString().split('T')[0];

    const latestDate = uniqueDates[0];
    // If user missed both today and yesterday, streak is broken
    if (latestDate !== todayStr && latestDate !== yesterdayStr) {
      return 0;
    }

    let streak = 0;
    let currentDate = new Date(latestDate);

    for (const dateStr of uniqueDates) {
      const d = new Date(dateStr);
      const diffTime = Math.abs(currentDate.getTime() - d.getTime());
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

      if (diffDays === 0) {
        streak = 1;
      } else if (diffDays === 1) {
        streak += 1;
        currentDate = d;
      } else {
        break; // Gap of more than 1 day, streak stops
      }
    }

    return streak;
  }

  private calculateCirclePulse(memories: { createdAt: Date }[]): number {
    if (memories.length === 0) return 0;

    // Check if no memory has been sent in the last 24 hours
    const lastMemoryTime = new Date(memories[0].createdAt).getTime();
    if (Date.now() - lastMemoryTime > 24 * 60 * 60 * 1000) {
      return 0; // Broken/restart if inactive for 24+ hrs
    }

    // Extract unique UTC dates (YYYY-MM-DD)
    const uniqueDates = Array.from(
      new Set(
        memories.map((m) => {
          const d = new Date(m.createdAt);
          return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(d.getUTCDate()).padStart(2, '0')}`;
        })
      )
    ).sort((a, b) => b.localeCompare(a));

    if (uniqueDates.length === 0) return 0;

    const todayStr = new Date().toISOString().split('T')[0];
    const yesterday = new Date();
    yesterday.setUTCDate(yesterday.getUTCDate() - 1);
    const yesterdayStr = yesterday.toISOString().split('T')[0];

    const latestDate = uniqueDates[0];
    if (latestDate !== todayStr && latestDate !== yesterdayStr) {
      return 0;
    }

    let streak = 0;
    let currentDate = new Date(latestDate);

    for (const dateStr of uniqueDates) {
      const d = new Date(dateStr);
      const diffTime = Math.abs(currentDate.getTime() - d.getTime());
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

      if (diffDays === 0) {
        streak = 1;
      } else if (diffDays === 1) {
        streak += 1;
        currentDate = d;
      } else {
        break;
      }
    }

    return streak;
  }
}
