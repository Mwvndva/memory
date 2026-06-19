import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import type { StringValue } from 'ms';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { JwtStrategy } from './strategies/jwt.strategy';
import { RateLimitGuard } from './guards/rate-limit.guard';

function resolveJwtExpiresIn(config: ConfigService): StringValue | number {
  const rawValue = config.get<string>('JWT_EXPIRES_IN')?.trim();
  if (!rawValue) {
    return '30d';
  }

  const parsed = Number(rawValue);
  if (Number.isFinite(parsed) && String(parsed) === rawValue) {
    return parsed;
  }

  return rawValue as StringValue;
}

@Module({
  imports: [
    ConfigModule,
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
        signOptions: {
          expiresIn: resolveJwtExpiresIn(config),
        },
      }),
    }),
  ],
  providers: [
    AuthService,
    JwtStrategy,
    RateLimitGuard,
    Reflector,
  ],
  controllers: [AuthController],
  exports: [JwtModule, PassportModule],
})
export class AuthModule {}
