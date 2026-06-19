import { Global, Module } from '@nestjs/common';
import { RedisService } from './redis.service';

/**
 * Global Redis module — imported once in AppModule, available everywhere.
 * Exports RedisService so any feature module (Auth, Gateway, Memories, etc.)
 * can inject it directly without re-importing this module.
 */
@Global()
@Module({
  providers: [RedisService],
  exports: [RedisService],
})
export class RedisModule {}
