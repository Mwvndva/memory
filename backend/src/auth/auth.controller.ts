import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import * as crypto from 'crypto';
import { AuthService } from './auth.service';
import { RateLimitGuard } from './guards/rate-limit.guard';
import { RateLimit } from './decorators/rate-limit.decorator';
import { JwtRefreshGuard } from './guards/jwt-refresh.guard';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { RefreshTokenPayload } from './strategies/jwt-refresh.strategy';
import { RedisService } from '../redis/redis.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';

// ─── Helper: camelCase user → snake_case response ──────────────────────────

function toSnakeUser(user: Record<string, any>) {
  return {
    id:         user.id,
    first_name: user.firstName,
    last_name:  user.lastName,
    username:   user.username,
    email:      user.email,
    phone:      user.phone,
    avatar_url: user.avatarUrl ?? null,
    created_at: user.createdAt,
  };
}

// ─── Helper: token pair → snake_case response ──────────────────────────────

function toSnakeTokens(tokens: { accessToken: string; refreshToken: string; expiresAt: number }) {
  return {
    access_token:  tokens.accessToken,
    refresh_token: tokens.refreshToken,
    expires_at:    tokens.expiresAt,   // Unix timestamp (seconds)
    token_type:    'Bearer',
  };
}

@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly redis: RedisService,
  ) {}

  // ─── POST /auth/register ─────────────────────────────────────────────────
  // Flutter sends: { first_name, last_name, username, email, phone, password }
  // Returns:       { tokens: { access_token, refresh_token, expires_at }, user: { id, ... } }

  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 5, windowSeconds: 3600 })
  @Post('register')
  async register(@Body() dto: RegisterDto) {
    const result = await this.authService.register(dto);
    return {
      tokens: toSnakeTokens(result.tokens),
      user:   toSnakeUser(result.user),
    };
  }

  // ─── POST /auth/login ────────────────────────────────────────────────────
  // Flutter sends: { identity: "<email_or_username>", password }
  // Returns:       { tokens: { access_token, refresh_token, expires_at }, user: { id, ... } }

  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 10, windowSeconds: 900 })
  @Post('login')
  @HttpCode(HttpStatus.OK)
  async login(@Body() dto: LoginDto) {
    const result = await this.authService.login(dto);
    return {
      tokens: toSnakeTokens(result.tokens),
      user:   toSnakeUser(result.user),
    };
  }

  // ─── POST /auth/refresh ──────────────────────────────────────────────────
  // Flutter sends: Authorization: Bearer <refresh_token>
  // Returns:       { tokens: { access_token, refresh_token, expires_at } }
  //
  // Protected by JwtRefreshGuard which validates:
  //   1. JWT signature (REFRESH_TOKEN_SECRET)
  //   2. tokenType === 'refresh' claim
  //   3. JTI is in the Redis allowlist (not revoked)
  //
  // On success the incoming refresh token is revoked and a brand-new pair
  // is issued (token rotation — prevents refresh token reuse attacks).

  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 30, windowSeconds: 900 })
  @UseGuards(JwtRefreshGuard)
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  async refresh(@Req() req: { user: RefreshTokenPayload }) {
    const { sub: userId, username, jti } = req.user;
    const tokens = await this.authService.refreshTokens(userId, username, jti);
    return { tokens: toSnakeTokens(tokens) };
  }

  // ─── POST /auth/logout ───────────────────────────────────────────────────
  // Flutter sends: Authorization: Bearer <refresh_token>
  // Returns:       { message: 'Logged out successfully' }
  //
  // Revokes only the presented refresh token's JTI (single-device logout).
  // The access token will naturally expire within 5 minutes.

  @UseGuards(JwtRefreshGuard)
  @Post('logout')
  @HttpCode(HttpStatus.OK)
  async logout(@Req() req: { user: RefreshTokenPayload }) {
    const { sub: userId, jti } = req.user;
    return this.authService.logout(userId, jti);
  }

  // ─── POST /auth/ws-ticket ───────────────────────────────────────────────
  // Flutter calls this right before opening a WebSocket connection.
  // Returns a short-lived opaque ticket (32-byte hex, 30-second TTL)
  // that the client passes as:  ws://<host>/ws?ticket=<ticket>
  //
  // This prevents the JWT from ever appearing in:
  //   - Sec-WebSocket-Protocol headers (logged by every proxy/CDN)
  //   - WebSocket upgrade request URLs (committed to access logs)
  //
  // The ticket is single-use (atomically consumed on first WS connection)
  // and expires in 30 seconds, making replay attacks impossible.

  @UseGuards(JwtAuthGuard)
  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 10, windowSeconds: 60 })
  @Post('ws-ticket')
  @HttpCode(HttpStatus.OK)
  async issueWsTicket(@Req() req: any) {
    const { id: userId, username } = req.user as { id: string; username: string };
    const ticket = crypto.randomBytes(32).toString('hex'); // 256 bits of entropy
    await this.redis.issueWsTicket(userId, username, ticket);
    return {
      ticket,
      expires_in: 30, // seconds
    };
  }

  // ─── GET /auth/username-check?username=xyz ───────────────────────────────
  // Flutter calls: /auth/username-check?username=<handle>
  // Returns:       { ok: boolean, message: string }

  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 20, windowSeconds: 60 })
  @Get('username-check')
  async checkUsername(@Query('username') username: string) {
    if (!username?.trim()) {
      return { ok: false, message: 'Username is required.' };
    }
    const cleanUsername = username.trim().replaceAll('@', '');
    const { available } = await this.authService.checkUsername(cleanUsername);
    return {
      ok: available,
      message: available
        ? `@${cleanUsername} is available.`
        : `@${cleanUsername} is taken.`,
    };
  }
}
