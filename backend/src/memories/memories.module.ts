import { Module } from '@nestjs/common';
import { MemoriesService } from './memories.service';
import { MemoriesController } from './memories.controller';
import { GatewayModule } from '../gateway/gateway.module';

@Module({
  imports: [GatewayModule],
  providers: [MemoriesService],
  controllers: [MemoriesController],
  exports: [MemoriesService],
})
export class MemoriesModule {}
