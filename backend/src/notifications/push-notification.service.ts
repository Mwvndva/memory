import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { initializeApp, cert, App, ServiceAccount } from 'firebase-admin/app';
import { getMessaging, Message } from 'firebase-admin/messaging';
import { buildNotificationContent } from './notification-content';
import { errorMessage } from '../common/errors';

@Injectable()
export class PushNotificationService implements OnModuleInit {
  private readonly logger = new Logger(PushNotificationService.name);
  private firebaseApp: App | null = null;

  constructor(private readonly prisma: PrismaService) {}

  onModuleInit() {
    const credentialsStr = process.env.FIREBASE_CREDENTIALS;
    if (credentialsStr) {
      try {
        const credentials = JSON.parse(credentialsStr) as ServiceAccount;
        this.firebaseApp = initializeApp({
          credential: cert(credentials),
        });
        this.logger.log('Firebase Admin SDK initialized successfully.');
      } catch (err) {
        this.logger.error(
          `Failed to initialize Firebase Admin SDK: ${errorMessage(err)}`,
        );
      }
    } else {
      this.logger.warn(
        'FIREBASE_CREDENTIALS not configured. Push notifications will be simulated.',
      );
    }
  }

  /**
   * Translates a WebSocket event payload to a human-readable title and body,
   * then sends a push notification.
   */
  async sendNotification(
    userId: string,
    event: string,
    payload: Record<string, unknown>,
  ): Promise<boolean> {
    // Shared with NotificationsService.record() so the push a user receives and
    // the row they later see in their history say exactly the same thing.
    const { title, body, data } = buildNotificationContent(
      event,
      payload ?? {},
    );
    return this.sendPush(userId, title, body, data);
  }

  /**
   * Direct wrapper around the Firebase Messaging API to target a user's fcmToken.
   */
  private async sendPush(
    userId: string,
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<boolean> {
    // Look up user fcmToken
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { fcmToken: true, username: true },
    });

    if (!user) {
      this.logger.warn(
        `User with ID="${userId}" not found. Cannot send push notification.`,
      );
      return false;
    }

    if (!user.fcmToken) {
      this.logger.warn(
        `User @${user.username} has no fcmToken registered. Push notification skipped.`,
      );
      return false;
    }

    if (this.firebaseApp) {
      try {
        const message: Message = {
          token: user.fcmToken,
          notification: {
            title,
            body,
          },
          data,
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        };

        const response = await getMessaging(this.firebaseApp).send(message);
        this.logger.log(
          `Successfully sent push notification to @${user.username}: messageId="${response}"`,
        );
        return true;
      } catch (err) {
        this.logger.error(
          `Error sending push notification to @${user.username}: ${errorMessage(err)}`,
        );
        return false;
      }
    } else {
      this.logger.log(
        `[SIMULATED PUSH] Sent to @${user.username} (Token="${user.fcmToken}"): Title="${title}", Body="${body}", Data=${JSON.stringify(
          data,
        )}`,
      );
      return true;
    }
  }
}
