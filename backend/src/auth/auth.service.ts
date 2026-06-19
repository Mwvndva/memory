import {
  BadRequestException,
  Injectable,
  ConflictException,
  UnauthorizedException,
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
    if (!dto.acceptedTerms) {
      throw new BadRequestException('You must accept the Terms and Conditions to register.');
    }

    // 1. Uniqueness checks (fast — username and email have unique indexes)
    const [existingEmail, existingUsername] = await Promise.all([
      this.prisma.user.findUnique({ where: { email: dto.email } }),
      this.prisma.user.findUnique({ where: { username: dto.username } }),
    ]);

    if (existingEmail)    throw new ConflictException('Email is already registered');
    if (existingUsername) throw new ConflictException('Username is already taken');

    // 2. Hash password with Argon2id
    const passwordHash = await argon2.hash(dto.password, ARGON2_OPTIONS);

    // 3. Persist user
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
        id: true, username: true, firstName: true, lastName: true, email: true,
      },
    });

    // 4. Issue token immediately (auto-login after registration)
    const token = this.issueToken(user.id, user.username);
    return { user, token };
  }

  // ─── Login ─────────────────────────────────────────────────────────────────

  async login(dto: LoginDto) {
    // Resolve by email or username
    const isEmail = dto.identifier.includes('@');
    const user = await this.prisma.user.findFirst({
      where: isEmail
        ? { email: dto.identifier }
        : { username: dto.identifier },
    });

    // Constant-time: always verify even if user not found (prevents timing attacks)
    const dummyHash = '$argon2id$v=19$m=19456,t=2,p=1$placeholder';
    const hashToVerify = user?.passwordHash ?? dummyHash;

    const passwordMatch = await argon2.verify(hashToVerify, dto.password);

    if (!user || !passwordMatch) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const token = this.issueToken(user.id, user.username);
    const { passwordHash: _, ...safeUser } = user;
    return { user: safeUser, token };
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  private issueToken(userId: string, username: string): string {
    return this.jwt.sign(
      { sub: userId, username },
      {
        secret: process.env.JWT_SECRET ?? 'change_me_in_production',
        expiresIn: (process.env.JWT_EXPIRES_IN ?? '30d') as any,
      },
    );
  }
}
