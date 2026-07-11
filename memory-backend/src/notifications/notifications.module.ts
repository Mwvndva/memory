import { Global, Module } from '@nestjs/common';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { PushNotificationService } from './push-notification.service';

/**
 * Global so the gateway and the job processor can record notification history
 * without importing this module and creating a cycle back through JobsModule.
 */
@Global()
@Module({
  controllers: [NotificationsController],
  providers: [NotificationsService, PushNotificationService],
  exports: [NotificationsService, PushNotificationService],
})
export class NotificationsModule {}
