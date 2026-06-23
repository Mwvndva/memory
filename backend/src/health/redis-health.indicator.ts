import { Injectable } from '@nestjs/common';
import { HealthCheckError, HealthIndicatorResult } from '@nestjs/terminus';
import { RedisService } from '../redis/redis.service';

@Injectable()
export class RedisHealthIndicator {
  constructor(private readonly redisService: RedisService) {}

  async isHealthy(key: string): Promise<HealthIndicatorResult> {
    try {
      const pong = await this.redisService.getClient().ping();
      if (pong !== 'PONG') {
        throw new Error(`Unexpected Redis ping response: ${pong}`);
      }
      return { [key]: { status: 'up' } };
    } catch (e) {
      throw new HealthCheckError('Redis check failed', e);
    }
  }
}

