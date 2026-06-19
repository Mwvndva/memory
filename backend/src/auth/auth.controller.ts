import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthService } from './auth.service';
import { RateLimitGuard } from './guards/rate-limit.guard';
import { RateLimit } from './decorators/rate-limit.decorator';

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

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  // ─── POST /auth/register ─────────────────────────────────────────────────
  // Flutter sends: { first_name, last_name, username, email, phone, password }
  // Returns:       { token, user: { id, first_name, ... } }

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
    return { token: result.token, user: toSnakeUser(result.user) };
  }

  // ─── POST /auth/login ────────────────────────────────────────────────────
  // Flutter sends: { identity: "<email_or_username>", password }
  // Returns:       { token, user: { id, first_name, ... } }

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
    return { token: result.token, user: toSnakeUser(result.user) };
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
