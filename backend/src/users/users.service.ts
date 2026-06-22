import { Injectable, NotFoundException, OnModuleInit, Logger } from '@nestjs/common';
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
export class UsersService implements OnModuleInit {
  private readonly logger = new Logger(UsersService.name);

  constructor(private readonly prisma: PrismaService) {}

  onModuleInit() {
    // Recalculate ranks once at startup after 10 seconds to avoid blocking main thread bootstrap
    setTimeout(() => {
      this.recalculateAllUserRanks().catch((err) => {
        this.logger.error(`[Startup Job] Failed to run initial rankings recalculation: ${err.message}`);
      });
    }, 1000 * 10);

    // Periodically run global rankings recalculation every 1 hour
    setInterval(() => {
      this.recalculateAllUserRanks().catch((err) => {
        this.logger.error(`[Background Job] Failed to recalculate all user ranks: ${err.message}`);
      });
    }, 1000 * 60 * 60);
  }

  // ─── Username availability ─────────────────────────────────────────────────

  async checkUsername(username: string): Promise<{ available: boolean }> {
    const existing = await this.prisma.user.findUnique({ where: { username } });
    return { available: !existing };
  }

  // ─── Profile retrieval (reads pre-cached stats — O(1)) ────────────────────
  async getProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        ...USER_SELECT,
        phone: true,
      },
    });
    if (!user) throw new NotFoundException('User not found');

    // Derive flag emoji from phone prefix (cached in DB as `country`)
    const flagEmoji = user.country || user.phone?.split(' ')[0] || '🇰🇪';

    // Compute circle pulse (consecutive days anyone in circle posted)
    const circlePulseDays = await this._getCirclePulseDays(userId);

    return {
      ...user,
      stats: {
        streakDays:     user.streakDays,
        circlePulseDays,
        countryRank:    user.countryRank,
        globalRank:     user.globalRank ?? null,
        flagEmoji,
      },
    };
  }

  /**
   * Recalculate and persist streak + global/country ranks for a single user.
   * Called after a memory is created so stats stay fresh without scanning
   * every user on every profile fetch.
   */
  async recalculateUserStats(userId: string) {
    this.logger.log(`[Recalculate Stats] Updating streak for userId="${userId}"`);
    // 1. Fetch this user's memories for streak calculation
    const memories = await this.prisma.memory.findMany({
      where: { creatorId: userId },
      select: { createdAt: true },
      orderBy: { createdAt: 'desc' },
    });

    const streak = this.calculateUserStreak(memories);

    // 2. Fetch country flag emoji from phone prefix
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { phone: true },
    });
    const country = user?.phone?.split(' ')[0] || '🇰🇪';

    // 3. Update the user's streakDays and country (ranks will be calculated by the background cron job)
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        streakDays: streak,
        country,
      },
    });

    this.logger.log(`[Recalculate Stats] User streak updated: userId="${userId}" streak=${streak} country=${country}`);
  }

  // ─── Profile update ────────────────────────────────────────────────────────
  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const data: any = {};
    if (dto.firstName !== undefined) data.firstName = dto.firstName;
    if (dto.first_name !== undefined) data.firstName = dto.first_name;
    if (dto.lastName !== undefined) data.lastName = dto.lastName;
    if (dto.last_name !== undefined) data.lastName = dto.last_name;
    if (dto.phone !== undefined) data.phone = dto.phone;
    if (dto.avatarUrl !== undefined) data.avatarUrl = dto.avatarUrl;
    if (dto.avatar_url !== undefined) data.avatarUrl = dto.avatar_url;

    if (data.phone) {
      data.country = data.phone.split(' ')[0] || '🇰🇪';
    }

    const user = await this.prisma.user.update({
      where: { id: userId },
      data,
      select: { ...USER_SELECT, phone: true },
    });

    const flagEmoji = user.country || user.phone?.split(' ')[0] || '🇰🇪';
    const circlePulseDays = await this._getCirclePulseDays(userId);

    return {
      ...user,
      stats: {
        streakDays:     user.streakDays,
        circlePulseDays,
        countryRank:    user.countryRank,
        globalRank:     user.globalRank ?? null,
        flagEmoji,
      },
    };
  }

  // ─── Search by phone numbers (contact sync) ────────────────────────────────
  async findByPhones(phones: string[]): Promise<{ id: string; username: string; firstName: string; lastName: string; phone: string; avatarUrl: string | null }[]> {
    // 1. Sanitize input phone numbers (digits only)
    const cleanInputs = phones
      .map((p) => p.replace(/\D/g, ''))
      .filter((p) => p.length >= 7); // Ignore very short numbers

    if (cleanInputs.length === 0) return [];

    // 2. Fetch all users from database
    const users = await this.prisma.user.findMany({
      select: {
        id: true,
        username: true,
        firstName: true,
        lastName: true,
        phone: true,
        avatarUrl: true,
      },
    });

    // 3. Match using suffix comparison (e.g., comparing last 9 digits or full match if shorter)
    const matched = users.filter((u) => {
      const cleanDbPhone = u.phone.replace(/\D/g, '');
      if (cleanDbPhone.length < 7) return false;

      return cleanInputs.some((input) => {
        const minLen = Math.min(cleanDbPhone.length, input.length, 9);
        const suffixDb = cleanDbPhone.substring(cleanDbPhone.length - minLen);
        const suffixInput = input.substring(input.length - minLen);
        return suffixDb === suffixInput;
      });
    });

    return matched;
  }

  // ─── Streak, Rank, and Pulse Stats Calculations ────────────────────────────
  async getUserStats(userId: string) {
    // 1. Fetch this user's pre-computed stats directly from database in O(1)
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        phone: true,
        streakDays: true,
        countryRank: true,
        globalRank: true,
      },
    });

    if (!user) throw new NotFoundException('User not found');

    const flagEmoji = user.phone.split(' ')[0] || '🇰🇪';

    // 2. Compute Circle Pulse (consecutive daily posts by anyone in circle)
    const circleMemberships = await this.prisma.circleMembership.findMany({
      where: { userId, accepted: true },
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
      streakDays: user.streakDays,
      circlePulseDays,
      countryRank: user.countryRank,
      globalRank: user.globalRank,
      flagEmoji,
    };
  }

  /**
   * Periodically recalculates globalRank and countryRank for all users in the system.
   * Runs in the background (e.g. hourly) to offload heavy calculations from the API request path.
   */
  async recalculateAllUserRanks() {
    this.logger.log(`[Rankings Job] Starting global rankings recalculation...`);
    const startTime = Date.now();

    // 1. Fetch all users with only necessary fields to minimize memory footprint
    const allUsers = await this.prisma.user.findMany({
      select: {
        id: true,
        phone: true,
        streakDays: true,
      },
    });

    if (allUsers.length === 0) return;

    // 2. Pre-process countries
    const userStreaks = allUsers.map((u) => {
      const country = u.phone?.split(' ')[0] || '🇰🇪';
      return {
        userId: u.id,
        streak: u.streakDays,
        country,
      };
    });

    // 3. Sort globally by streak (descending)
    userStreaks.sort((a, b) => b.streak - a.streak);

    // 4. Compute global ranks
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

    // 5. Compute country ranks
    const countryGroups = new Map<string, typeof userStreaks>();
    for (const u of userStreaks) {
      if (!countryGroups.has(u.country)) {
        countryGroups.set(u.country, []);
      }
      countryGroups.get(u.country)!.push(u);
    }

    const countryRanksMap = new Map<string, number>();
    for (const [, group] of countryGroups.entries()) {
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

    // 6. Update all users in the database using batches to avoid lock escalations
    const batchSize = 250;
    for (let i = 0; i < userStreaks.length; i += batchSize) {
      const batch = userStreaks.slice(i, i + batchSize);
      await this.prisma.$transaction(
        batch.map((u) => {
          const gRank = globalRanksMap.get(u.userId) ?? 1;
          const cRank = countryRanksMap.get(u.userId) ?? 1;
          return this.prisma.user.update({
            where: { id: u.userId },
            data: {
              country: u.country,
              countryRank: cRank,
              globalRank: gRank <= 300000 ? gRank : null,
            },
          });
        })
      );
    }

    const duration = Date.now() - startTime;
    this.logger.log(`[Rankings Job] Global rankings recalculation complete (processed ${allUsers.length} users in ${duration}ms).`);
  }

  // ─── Circle Pulse (private helper) ───────────────────────────────────
  private async _getCirclePulseDays(userId: string): Promise<number> {
    const circleMemberships = await this.prisma.circleMembership.findMany({
      where: { userId, accepted: true },
      select: { memberId: true },
    });
    const circleUserIds = [userId, ...circleMemberships.map((m) => m.memberId)];
    const circleMemories = await this.prisma.memory.findMany({
      where: { creatorId: { in: circleUserIds } },
      select: { createdAt: true },
      orderBy: { createdAt: 'desc' },
    });
    return this.calculateCirclePulse(circleMemories);
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
