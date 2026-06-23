import { Module, Global, forwardRef } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { JobsService } from './jobs.service';
import { HeavyOpsProcessor } from './heavy-ops.processor';
import { UsersModule } from '../users/users.module';
import { CirclesModule } from '../circles/circles.module';
import { GatewayModule } from '../gateway/gateway.module';
import { PushNotificationService } from '../notifications/push-notification.service';

@Global()
@Module({
  imports: [
    BullModule.registerQueue({
      name: 'heavy-ops',
    }),
    UsersModule,
    forwardRef(() => CirclesModule),
    GatewayModule,
  ],
  providers: [JobsService, HeavyOpsProcessor, PushNotificationService],
  exports: [JobsService, PushNotificationService],
})
export class JobsModule {}

