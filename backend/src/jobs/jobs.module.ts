import { Module, Global, forwardRef } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { JobsService } from './jobs.service';
import { HeavyOpsProcessor } from './heavy-ops.processor';
import { UsersModule } from '../users/users.module';
import { CirclesModule } from '../circles/circles.module';
import { GatewayModule } from '../gateway/gateway.module';

// PushNotificationService and NotificationsService come from the @Global
// NotificationsModule; providing PushNotificationService here as well would
// create a second, independent Firebase instance.
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
  providers: [JobsService, HeavyOpsProcessor],
  exports: [JobsService],
})
export class JobsModule {}
