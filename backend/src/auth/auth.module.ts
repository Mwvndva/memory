import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { Reflector } from '@nestjs/core';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { JwtStrategy } from './strategies/jwt.strategy';
import { RateLimitGuard } from './guards/rate-limit.guard';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'jwt' }),
    // Secret passed per-call in AuthService so it picks up from env at runtime
    JwtModule.register({}),
  ],
  providers: [
    AuthService,
    JwtStrategy,
    RateLimitGuard, // needs Reflector + RedisService (global)
    Reflector,      // required by RateLimitGuard to read @RateLimit() metadata
  ],
  controllers: [AuthController],
  exports: [JwtModule, PassportModule],
})
export class AuthModule {}
