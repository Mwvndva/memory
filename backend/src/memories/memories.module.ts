import { Module, forwardRef } from '@nestjs/common';
import { MemoriesService } from './memories.service';
import { MemoriesController } from './memories.controller';
import { GatewayModule } from '../gateway/gateway.module';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [GatewayModule, forwardRef(() => UsersModule)],
  providers: [MemoriesService],
  controllers: [MemoriesController],
  exports: [MemoriesService],
})
export class MemoriesModule {}
