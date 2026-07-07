import {
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RedisService } from '../../redis/redis.service';
import {
  RATE_LIMIT_KEY,
  RateLimitOptions,
} from '../decorators/rate-limit.decorator';

@Injectable()
export class RateLimitGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly redisService: RedisService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    // Read options set by @RateLimit() on the handler
    const options = this.reflector.get<RateLimitOptions>(
      RATE_LIMIT_KEY,
      context.getHandler(),
    );

    // If no @RateLimit() decorator, allow through
    if (!options) return true;

    const request = context.switchToHttp().getRequest();

    // Use Express's resolved client IP. With `trust proxy` configured in
    // main.ts, request.ip already reflects the correct X-Forwarded-For hop.
    // Reading the raw XFF header here would let a client spoof it and mint a
    // fresh rate-limit bucket per forged IP, bypassing the limit entirely.
    const rawIp: string = request.ip ?? 'unknown';

    // Build a bucket key scoped to: class + handler + IP
    // e.g. "AuthController:login:192.168.1.1"
    const bucketKey = `${context.getClass().name}:${context.getHandler().name}:${rawIp}`;

    const { count, ttl } = await this.redisService.rateLimit(
      bucketKey,
      options.windowSeconds,
    );

    if (count > options.limit) {
      throw new HttpException(
        {
          statusCode: HttpStatus.TOO_MANY_REQUESTS,
          error: 'Too Many Requests',
          message: `Rate limit exceeded. Try again in ${ttl} second${ttl === 1 ? '' : 's'}.`,
          retryAfter: ttl,
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    return true;
  }
}
