import {
  BadRequestException,
  Injectable,
  ConflictException,
  UnauthorizedException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as argon2 from 'argon2';
import * as crypto from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { normalizePhone } from '../users/users.service';

/**
 * Argon2id configuration — OWASP recommended minimums:
 * memory: 19 MiB, iterations: 2, parallelism: 1
 */
const ARGON2_OPTIONS: argon2.Options & { raw?: false } = {
  type: argon2.argon2id,
  memoryCost: 19456,   // 19 MiB
  timeCost: 2,         // iterations
  parallelism: 1,
};

/**
 * A real Argon2id hash used for constant-time dummy verification when a
 * login attempt targets a non-existent user.  Pre-computed once at module
 * load so the first request doesn't need to pay the hashing cost.
 */
let _dummyHash: string | null = null;
async function getDummyHash(): Promise<string> {
  if (!_dummyHash) {
    _dummyHash = await argon2.hash('__dummy_password__', ARGON2_OPTIONS);
  }
  return _dummyHash;
}

// ─── Token pair shape returned to the client ──────────────────────────────────
export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  /** Unix timestamp (seconds) when the access token expires. */
  expiresAt: number;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly redis: RedisService,
  ) {}

  // ─── Username availability ─────────────────────────────────────────────────

  async checkUsername(username: string): Promise<{ available: boolean }> {
    const existing = await this.prisma.user.findUnique({ where: { username } });
    return { available: !existing };
  }

  // ─── Registration ──────────────────────────────────────────────────────────

  async register(dto: RegisterDto) {
    const maskEmail = (emailStr: string) => {
      const parts = emailStr.split('@');
      if (parts.length !== 2) return '***';
      const name = parts[0];
      const domain = parts[1];
      const maskedName = name.length > 2 ? `${name.slice(0, 2)}***` : '***';
      return `${maskedName}@${domain}`;
    };
    this.logger.log(`[Register] New registration request for username="${dto.username}" email="${maskEmail(dto.email)}"`);
    if (!dto.acceptedTerms) {
      this.logger.warn(`[Register] Registration failed: Terms and Conditions not accepted`);
      throw new BadRequestException('You must accept the Terms and Conditions to register.');
    }

    // 1. Uniqueness checks (fast — username and email have unique indexes)
    this.logger.log(`[Register] Step 1: Checking uniqueness`);
    const [existingEmail, existingUsername] = await Promise.all([
      this.prisma.user.findUnique({ where: { email: dto.email } }),
      this.prisma.user.findUnique({ where: { username: dto.username } }),
    ]);

    if (existingEmail) {
      this.logger.warn(`[Register] Registration failed: email already exists`);
      throw new ConflictException('Email is already registered');
    }
    if (existingUsername) {
      this.logger.warn(`[Register] Registration failed: username="${dto.username}" already exists`);
      throw new ConflictException('Username is already taken');
    }

    // 2. Hash password with Argon2id
    this.logger.log(`[Register] Step 2: Hashing password using Argon2id`);
    const passwordHash = await argon2.hash(dto.password, ARGON2_OPTIONS);

    // 3. Persist user
    this.logger.log(`[Register] Step 3: Saving user record in database`);
    const flagEmoji = dto.phone.split(' ')[0] || '🇰🇪';
    const firstName = dto.first_name ?? dto.firstName ?? '';
    const lastName = dto.last_name ?? dto.lastName ?? '';
    const user = await this.prisma.user.create({
      data: {
        firstName,
        lastName,
        username:     dto.username,
        email:        dto.email,
        phone:        dto.phone,
        phoneNormalized: normalizePhone(dto.phone),
        country:      flagEmoji,
        passwordHash,
        acceptedTermsAt: new Date(),
      },
      select: {
        id: true,
        username: true,
        firstName: true,
        lastName: true,
        email: true,
        phone: true,
        avatarUrl: true,
        createdAt: true,
      },
    });

    // 4. Issue token pair immediately (auto-login after registration)
    this.logger.log(`[Register] Step 4: Issuing token pair for userId="${user.id}"`);
    const tokens = await this.issueTokenPair(user.id, user.username);
    this.logger.log(`[Register] User registered successfully: userId="${user.id}"`);
    return { user, tokens };
  }

  // ─── Login ─────────────────────────────────────────────────────────────────

  async login(dto: LoginDto) {
    this.logger.log(`[Login] New login request`);
    // Resolve by email or username (identity or identifier)
    const identifier = dto.identity ?? dto.identifier ?? '';
    const isEmail = identifier.includes('@');
    this.logger.log(`[Login] Step 1: Finding user by ${isEmail ? 'email' : 'username'}`);
    const user = await this.prisma.user.findFirst({
      where: isEmail
        ? { email: identifier }
        : { username: identifier },
    });

    // Constant-time: always verify even if user not found (prevents timing attacks).
    // Use a pre-computed real Argon2id hash so full verification cost is always paid.
    const hashToVerify = user?.passwordHash ?? await getDummyHash();

    this.logger.log(`[Login] Step 2: Verifying password`);
    const passwordMatch = await argon2.verify(hashToVerify, dto.password);

    if (!user || !passwordMatch) {
      this.logger.warn(`[Login] Login failed: Invalid credentials`);
      throw new UnauthorizedException('Invalid credentials');
    }

    this.logger.log(`[Login] Step 3: Issuing token pair for userId="${user.id}"`);
    const tokens = await this.issueTokenPair(user.id, user.username);
    const { passwordHash: _, ...safeUser } = user;
    this.logger.log(`[Login] User logged in successfully: username="${user.username}"`);
    return { user: safeUser, tokens };
  }

  // ─── Refresh ───────────────────────────────────────────────────────────────

  /**
   * POST /auth/refresh
   *
   * Called with a valid refresh token (verified by JwtRefreshGuard + JwtRefreshStrategy).
   * The guard has already:
   *  1. Verified the JWT signature against REFRESH_TOKEN_SECRET.
   *  2. Confirmed tokenType === 'refresh'.
   *  3. Confirmed the JTI is in the Redis allowlist.
   *
   * This method performs token rotation:
   *  - Revokes the incoming JTI from Redis.
   *  - Issues a brand-new token pair (new access + refresh with a new JTI).
   *
   * If the same refresh token is replayed after rotation, the Redis check
   * in the strategy will reject it, preventing refresh token reuse.
   */
  async refreshTokens(userId: string, username: string, oldJti: string): Promise<TokenPair> {
    this.logger.log(`[Refresh] Rotating token pair for userId="${userId}"`);

    // Revoke the old refresh token JTI (token rotation — one-time use)
    await this.redis.revokeRefreshToken(userId, oldJti);

    // Issue a fresh pair
    const tokens = await this.issueTokenPair(userId, username);
    this.logger.log(`[Refresh] Token pair rotated successfully for userId="${userId}"`);
    return tokens;
  }

  // ─── Logout ────────────────────────────────────────────────────────────────

  /**
   * POST /auth/logout
   *
   * Single-device logout: revokes only the presented refresh token's JTI.
   * The access token will naturally expire within 5 minutes.
   * (For "logout everywhere", use revokeAllUserTokens — reserved for account
   *  compromise scenarios or an explicit "sign out all devices" UI action.)
   */
  async logout(userId: string, jti: string): Promise<{ message: string }> {
    this.logger.log(`[Logout] Revoking refresh token for userId="${userId}" jti="${jti}"`);
    await this.redis.revokeRefreshToken(userId, jti);
    this.logger.log(`[Logout] Logout successful for userId="${userId}"`);
    return { message: 'Logged out successfully' };
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  /**
   * Issues an access + refresh token pair and stores the refresh JTI in Redis.
   *
   * Access token:   signed with JWT_SECRET,         expires in 5 minutes.
   * Refresh token:  signed with REFRESH_TOKEN_SECRET, expires in 30 days.
   *                 Carries a unique `jti` (UUID v4) stored in the Redis
   *                 allowlist so it can be individually revoked.
   */
  private async issueTokenPair(userId: string, username: string): Promise<TokenPair> {
    const jti = crypto.randomUUID();
    const now = Math.floor(Date.now() / 1000);
    // Access token: 5 minutes
    const ACCESS_TTL_SECONDS = 5 * 60;
    const expiresAt = now + ACCESS_TTL_SECONDS;

    const accessToken = this.jwt.sign(
      { sub: userId, username },
      { expiresIn: '5m' },
    );

    const refreshSecret = this.config.get<string>('REFRESH_TOKEN_SECRET') || (this.config.get<string>('JWT_SECRET') ? this.config.get<string>('JWT_SECRET') + '-refresh' : 'fallback-refresh-secret');
    const refreshToken = this.jwt.sign(
      { sub: userId, username, jti, tokenType: 'refresh' },
      { secret: refreshSecret, expiresIn: '30d' },
    );


    // Persist JTI in Redis allowlist (enables per-device revocation)
    await this.redis.storeRefreshToken(userId, jti);

    return { accessToken, refreshToken, expiresAt };
  }
}
