import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { Request } from 'express';
import { RedisService } from '../../redis/redis.service';

export type RefreshTokenPayload = {
  sub: string; // userId
  username: string;
  jti: string; // unique token ID used for allowlist validation
  tokenType: 'refresh';
};

/**
 * 'jwt-refresh' Passport strategy.
 *
 * Validates that:
 *  1. The Bearer token in the Authorization header is a valid JWT signed with
 *     REFRESH_TOKEN_SECRET (separate from the access-token secret).
 *  2. The token carries tokenType === 'refresh' (prevents using an access
 *     token on the refresh endpoint and vice versa).
 *  3. The token's JTI is present in the Redis allowlist for this user
 *     (revocation check — ensures logout/rotation has not already invalidated it).
 */
@Injectable()
export class JwtRefreshStrategy extends PassportStrategy(
  Strategy,
  'jwt-refresh',
) {
  constructor(
    configService: ConfigService,
    private readonly redisService: RedisService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey:
        configService.get<string>('REFRESH_TOKEN_SECRET') ||
        (configService.get<string>('JWT_SECRET')
          ? configService.get<string>('JWT_SECRET') + '-refresh'
          : 'fallback-refresh-secret'),
      algorithms: ['HS256'], // pin algorithm — reject alg confusion / 'none'
      passReqToCallback: false,
    });
  }

  async validate(payload: RefreshTokenPayload): Promise<RefreshTokenPayload> {
    // Guard: reject access tokens sent to the refresh endpoint
    if (payload.tokenType !== 'refresh') {
      throw new UnauthorizedException('Invalid token type');
    }

    // Guard: reject tokens that have been revoked (logout / rotation)
    const isValid = await this.redisService.validateRefreshToken(
      payload.sub,
      payload.jti,
    );
    if (!isValid) {
      throw new UnauthorizedException('Refresh token has been revoked');
    }

    return payload;
  }
}
