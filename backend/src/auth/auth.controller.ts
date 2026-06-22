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
import { AuthService } from './auth.service';
import { RateLimitGuard } from './guards/rate-limit.guard';
import { RateLimit } from './decorators/rate-limit.decorator';
import { JwtRefreshGuard } from './guards/jwt-refresh.guard';
import { RefreshTokenPayload } from './strategies/jwt-refresh.strategy';

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
  constructor(private readonly authService: AuthService) {}

  // ─── POST /auth/register ─────────────────────────────────────────────────
  // Flutter sends: { first_name, last_name, username, email, phone, password }
  // Returns:       { tokens: { access_token, refresh_token, expires_at }, user: { id, ... } }

  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 5, windowSeconds: 3600 })
  @Post('register')
  async register(@Body() body: any) {
    const result = await this.authService.register({
      firstName: body.first_name ?? body.firstName,
      lastName:  body.last_name  ?? body.lastName,
      username:  body.username,
      email:     body.email,
      phone:     body.phone,
      password:  body.password,
      acceptedTerms: body.accepted_terms ?? body.acceptedTerms,
    });
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
  async login(@Body() body: any) {
    // Accept both 'identity' (Flutter) and 'identifier' (legacy) field names
    const identifier = body.identity ?? body.identifier;
    const result = await this.authService.login({
      identifier,
      password: body.password,
    });
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

  // ─── GET /auth/username-check?username=xyz ───────────────────────────────
  // Flutter calls: /auth/username-check?username=<handle>
  // Returns:       { ok: boolean, message: string }

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
