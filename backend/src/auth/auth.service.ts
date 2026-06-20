import {
  BadRequestException,
  Injectable,
  ConflictException,
  UnauthorizedException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as argon2 from 'argon2';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';

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

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  // ─── Username availability ─────────────────────────────────────────────────

  async checkUsername(username: string): Promise<{ available: boolean }> {
    const existing = await this.prisma.user.findUnique({ where: { username } });
    return { available: !existing };
  }

  // ─── Registration ──────────────────────────────────────────────────────────

  async register(dto: RegisterDto) {
    this.logger.log(`[Register] New registration request for username="${dto.username}" email="${dto.email}"`);
    if (!dto.acceptedTerms) {
      this.logger.warn(`[Register] Registration failed: Terms and Conditions not accepted`);
      throw new BadRequestException('You must accept the Terms and Conditions to register.');
    }

    // 1. Uniqueness checks (fast — username and email have unique indexes)
    this.logger.log(`[Register] Step 1: Checking uniqueness for email="${dto.email}", username="${dto.username}"`);
    const [existingEmail, existingUsername] = await Promise.all([
      this.prisma.user.findUnique({ where: { email: dto.email } }),
      this.prisma.user.findUnique({ where: { username: dto.username } }),
    ]);

    if (existingEmail) {
      this.logger.warn(`[Register] Registration failed: email="${dto.email}" already exists`);
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
    const user = await this.prisma.user.create({
      data: {
        firstName:    dto.firstName,
        lastName:     dto.lastName,
        username:     dto.username,
        email:        dto.email,
        phone:        dto.phone,
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

    // 4. Issue token immediately (auto-login after registration)
    this.logger.log(`[Register] Step 4: Issuing auto-login token for userId="${user.id}"`);
    const token = this.issueToken(user.id, user.username);
    this.logger.log(`[Register] Step 5: User registered successfully: userId="${user.id}"`);
    return { user, token };
  }

  // ─── Login ─────────────────────────────────────────────────────────────────

  async login(dto: LoginDto) {
    this.logger.log(`[Login] New login request for identifier="${dto.identifier}"`);
    // Resolve by email or username
    const isEmail = dto.identifier.includes('@');
    this.logger.log(`[Login] Step 1: Finding user by ${isEmail ? 'email' : 'username'}`);
    const user = await this.prisma.user.findFirst({
      where: isEmail
        ? { email: dto.identifier }
        : { username: dto.identifier },
    });

    // Constant-time: always verify even if user not found (prevents timing attacks)
    const dummyHash = '$argon2id$v=19$m=19456,t=2,p=1$placeholder';
    const hashToVerify = user?.passwordHash ?? dummyHash;

    this.logger.log(`[Login] Step 2: Verifying password matching for user="${user?.username || 'not_found'}"`);
    const passwordMatch = await argon2.verify(hashToVerify, dto.password);

    if (!user || !passwordMatch) {
      this.logger.warn(`[Login] Login failed: Invalid credentials for identifier="${dto.identifier}"`);
      throw new UnauthorizedException('Invalid credentials');
    }

    this.logger.log(`[Login] Step 3: Issuing token for userId="${user.id}"`);
    const token = this.issueToken(user.id, user.username);
    const { passwordHash: _, ...safeUser } = user;
    this.logger.log(`[Login] User logged in successfully: username="${user.username}"`);
    return { user: safeUser, token };
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  private issueToken(userId: string, username: string): string {
    return this.jwt.sign({ sub: userId, username });
  }
}
