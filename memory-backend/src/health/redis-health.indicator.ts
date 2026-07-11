import { Injectable } from '@nestjs/common';
import { HealthCheckError, HealthIndicatorResult } from '@nestjs/terminus';
import { RedisService } from '../redis/redis.service';

@Injectable()
export class RedisHealthIndicator {
  constructor(private readonly redisService: RedisService) {}

  async isHealthy(key: string): Promise<HealthIndicatorResult> {
    try {
      // Typed as string, not the 'PONG' literal: inside the guard below the
      // literal type narrows to `never` and cannot be interpolated.
      const pong: string = await this.redisService.getClient().ping();
      if (pong !== 'PONG') {
        throw new Error(`Unexpected Redis ping response: ${pong}`);
      }
      return { [key]: { status: 'up' } };
    } catch (e) {
      throw new HealthCheckError('Redis check failed', e);
    }
  }
}
