import { Injectable, NotFoundException, OnModuleInit, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { parsePhoneNumberFromString } from 'libphonenumber-js';

// Cache key builders + TTLs for profile reads (see getProfile/getPublicProfile).
const profileCacheKey = (userId: string) => `profile:${userId}`;
const publicProfileCacheKey = (userId: string) => `pubprofile:${userId}`;
const PROFILE_TTL_SECONDS = 60;
const PUBLIC_PROFILE_TTL_SECONDS = 120;

export function normalizePhone(phone: string): string {
  if (!phone) return '';
  if (phone.startsWith('deleted-') || phone.startsWith('del-')) {
    return 'deleted';
  }
  let parsed = parsePhoneNumberFromString(phone);
  if (!parsed && !phone.startsWith('+')) {
    const parsedKE = parsePhoneNumberFromString(phone, 'KE');
    if (parsedKE && parsedKE.isValid()) {
      parsed = parsedKE;
    } else {
      const parsedUS = parsePhoneNumberFromString(phone, 'US');
      if (parsedUS && parsedUS.isValid()) {
        parsed = parsedUS;
      }
    }
  }
  let result: string;
  if (parsed && parsed.isValid()) {
    result = parsed.format('E.164');
  } else {
    const digits = phone.replace(/\D/g, '');
    result = phone.startsWith('+') ? `+${digits}` : digits;
  }
  
  if (result.length > 20) {
    console.warn(`[normalizePhone] Phone number "${phone}" normalized to "${result}" which exceeds 20 characters. Truncating to 20 characters.`);
    return result.slice(0, 20);
  }
  return result;
}

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

/**
 * Fields safe to expose about *another* user to any authenticated caller.
 * Deliberately excludes PII (email, phone) — those belong only to the
 * owner via /users/me. Used by GET /users/:id.
 */
const PUBLIC_USER_SELECT = {
  id: true,
  firstName: true,
  lastName: true,
  username: true,
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

  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  onModuleInit() {
    // NOTE: global rankings recalculation is now driven by the cluster-safe
    // BullMQ repeatable job 'recalculate-all-ranks' (see JobsService) so it
    // runs once across all instances instead of once per instance.

    // Backfill normalized phones for legacy users (idempotent, cheap)
    this.backfillNormalizedPhones().catch((err) => {
      this.logger.error(`[Startup Job] Failed to backfill normalized phone numbers: ${err.message}`);
    });
  }

  async backfillNormalizedPhones() {
    this.logger.log(`[Backfill Job] Checking for users missing normalized phone numbers...`);
    const missing = await this.prisma.user.findMany({
      where: { phoneNormalized: "" },
      select: { id: true, phone: true }
    });

    if (missing.length === 0) {
      this.logger.log(`[Backfill Job] No users require phone normalization backfill.`);
      return;
    }

    this.logger.log(`[Backfill Job] Found ${missing.length} users needing phone normalization.`);

    const batchSize = 250;
    for (let i = 0; i < missing.length; i += batchSize) {
      const batch = missing.slice(i, i + batchSize);
      await this.prisma.$transaction(
        batch.map((u) => {
          return this.prisma.user.update({
            where: { id: u.id },
            data: { phoneNormalized: normalizePhone(u.phone) }
          });
        })
      );
    }
    this.logger.log(`[Backfill Job] Completed phone normalization backfill.`);
  }

  // ─── Username availability ─────────────────────────────────────────────────

  async checkUsername(username: string): Promise<{ available: boolean }> {
    const existing = await this.prisma.user.findUnique({ where: { username } });
    return { available: !existing };
  }

  // ─── Profile retrieval (reads pre-cached stats — O(1)) ────────────────────
  // Cached in Redis (60s) — this path also runs the unbounded circle-pulse
  // query, so caching removes it from the hot per-request path. Busted on
  // updateProfile / deleteAccount.
  async getProfile(userId: string) {
    const cacheKey = profileCacheKey(userId);
    const cached = await this.redis.cacheGetJson<Record<string, unknown>>(cacheKey);
    if (cached) return cached;

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

    const result = {
      ...user,
      stats: {
        streakDays:     user.streakDays,
        circlePulseDays,
        countryRank:    user.countryRank,
        globalRank:     user.globalRank ?? null,
        flagEmoji,
      },
    };
    await this.redis.cacheSetJson(cacheKey, result, PROFILE_TTL_SECONDS);
    return result;
  }

  // ─── Public profile (safe for any authenticated caller) ───────────────────
  // Returns only non-PII fields — no email, no phone. Used by GET /users/:id.
  // Cached in Redis (120s) — public data changes rarely. Busted on writes.
  async getPublicProfile(userId: string) {
    const cacheKey = publicProfileCacheKey(userId);
    const cached = await this.redis.cacheGetJson<Record<string, unknown>>(cacheKey);
    if (cached) return cached;

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: PUBLIC_USER_SELECT,
    });
    if (!user) throw new NotFoundException('User not found');

    const flagEmoji = user.country || '🇰🇪';

    const result = {
      ...user,
      stats: {
        streakDays:  user.streakDays,
        countryRank: user.countryRank,
        globalRank:  user.globalRank ?? null,
        flagEmoji,
      },
    };
    await this.redis.cacheSetJson(cacheKey, result, PUBLIC_PROFILE_TTL_SECONDS);
    return result;
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
    if (dto.phone !== undefined) {
      data.phone = dto.phone;
      data.phoneNormalized = normalizePhone(dto.phone);
    }
    if (dto.avatarUrl !== undefined) data.avatarUrl = dto.avatarUrl;
    if (dto.avatar_url !== undefined) data.avatarUrl = dto.avatar_url;
    if (dto.fcmToken !== undefined) data.fcmToken = dto.fcmToken;
    if (dto.fcm_token !== undefined) data.fcmToken = dto.fcm_token;

    if (data.phone) {
      data.country = data.phone.split(' ')[0] || '🇰🇪';
    }

    const user = await this.prisma.user.update({
      where: { id: userId },
      data,
      select: { ...USER_SELECT, phone: true },
    });

    // Write-through invalidation so edits are reflected immediately.
    await this.redis.cacheDel(profileCacheKey(userId), publicProfileCacheKey(userId));

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
    // 1. Sanitize input phone numbers (digits only) and normalize them
    const cleanInputs = phones
      .map((p) => normalizePhone(p))
      .filter((p) => p.length >= 7); // Ignore very short numbers

    if (cleanInputs.length === 0) return [];

    // 2. Fetch users in chunks of 500 to keep the IN query size bounded
    const chunkSize = 500;
    const matched: { id: string; username: string; firstName: string; lastName: string; phone: string; avatarUrl: string | null }[] = [];

    for (let i = 0; i < cleanInputs.length; i += chunkSize) {
      const chunk = cleanInputs.slice(i, i + chunkSize);
      const chunkUsers = await this.prisma.user.findMany({
        where: {
          phoneNormalized: {
            in: chunk,
          },
        },
        select: {
          id: true,
          username: true,
          firstName: true,
          lastName: true,
          phone: true,
          avatarUrl: true,
        },
      });
      matched.push(...chunkUsers);
    }

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

  async deleteAccount(userId: string) {
    this.logger.log(`[GDPR Delete] Request to delete account for userId="${userId}"`);
    
    // 1. Verify user exists
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    // 2. Anonymize/wipe sensitive fields + Soft-delete associated user data
    const anonymizedEmail = `deleted-${userId}@erasure.example.com`;
    const anonymizedPhone = `del-${userId.slice(0, 12)}`;
    
    await this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: userId },
        data: {
          firstName: 'Deleted',
          lastName: 'User',
          username: `deleted_${userId.slice(0, 8)}`,
          email: anonymizedEmail,
          phone: anonymizedPhone,
          phoneNormalized: anonymizedPhone,
          avatarUrl: null,
          deletedAt: new Date(),
        },
      });

      // Soft-delete memories
      await tx.memory.updateMany({
        where: { creatorId: userId, deletedAt: null },
        data: { deletedAt: new Date() },
      });

      // Soft-delete messages sent or received by this user
      await tx.message.updateMany({
        where: {
          OR: [{ senderId: userId }, { receiverId: userId }],
          deletedAt: null,
        },
        data: { deletedAt: new Date() },
      });

      // Soft-delete circle memberships
      await tx.circleMembership.updateMany({
        where: {
          OR: [{ userId }, { memberId: userId }],
          deletedAt: null,
        },
        data: { deletedAt: new Date() },
      });
    });

    // Invalidate any cached profile views for this user.
    await this.redis.cacheDel(profileCacheKey(userId), publicProfileCacheKey(userId));

    this.logger.log(`[GDPR Delete] User userId="${userId}" successfully anonymized and soft-deleted.`);
    return { success: true, message: 'Account deleted and PII anonymized.' };
  }

  async exportUserData(userId: string) {
    this.logger.log(`[GDPR Export] Data export request for userId="${userId}"`);
    
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        memories: {
          where: { deletedAt: null },
        },
        sentMessages: {
          where: { deletedAt: null },
        },
        receivedMessages: {
          where: { deletedAt: null },
        },
        userMemberships: {
          where: { deletedAt: null },
        },
      },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    // Build a clean portable JSON payload of user's personal data
    return {
      profile: {
        id: user.id,
        firstName: user.firstName,
        lastName: user.lastName,
        username: user.username,
        email: user.email,
        phone: user.phone,
        createdAt: user.createdAt,
      },
      memories: user.memories.map(m => ({
        id: m.id,
        caption: m.caption,
        videoUrl: m.videoUrl,
        gradientColors: m.gradientColors,
        createdAt: m.createdAt,
      })),
      sentMessages: user.sentMessages.map(msg => ({
        id: msg.id,
        receiverId: msg.receiverId,
        text: msg.text,
        timestamp: msg.timestamp,
      })),
      receivedMessages: user.receivedMessages.map(msg => ({
        id: msg.id,
        senderId: msg.senderId,
        text: msg.text,
        timestamp: msg.timestamp,
      })),
      circleMemberships: user.userMemberships.map(cm => ({
        id: cm.id,
        memberId: cm.memberId,
        accepted: cm.accepted,
        createdAt: cm.createdAt,
      })),
    };
  }
}

