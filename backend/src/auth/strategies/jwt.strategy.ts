import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

type JwtPayload = {
  sub: string;
  username: string;
  /** JTI of the refresh session that minted this access token. */
  sid?: string;
};

type JwtUser = {
  id: string;
  sub: string;
  username: string;
  /** Absent on tokens issued before `sid` was introduced. */
  sid?: string;
};

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(configService: ConfigService) {
    const secret = configService.getOrThrow<string>('JWT_SECRET');

    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: secret,
      algorithms: ['HS256'], // pin algorithm — reject alg confusion / 'none'
    });
  }

  validate(payload: JwtPayload): JwtUser {
    return {
      id: payload.sub,
      sub: payload.sub,
      username: payload.username,
      sid: payload.sid,
    };
  }
}
