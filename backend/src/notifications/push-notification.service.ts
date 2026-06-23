import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { initializeApp, cert, App } from 'firebase-admin/app';
import { getMessaging, Message } from 'firebase-admin/messaging';

@Injectable()
export class PushNotificationService implements OnModuleInit {
  private readonly logger = new Logger(PushNotificationService.name);
  private firebaseApp: App | null = null;

  constructor(private readonly prisma: PrismaService) {}

  onModuleInit() {
    const credentialsStr = process.env.FIREBASE_CREDENTIALS;
    if (credentialsStr) {
      try {
        const credentials = JSON.parse(credentialsStr);
        this.firebaseApp = initializeApp({
          credential: cert(credentials),
        });
        this.logger.log('Firebase Admin SDK initialized successfully.');
      } catch (err) {
        this.logger.error(`Failed to initialize Firebase Admin SDK: ${err.message}`);
      }
    } else {
      this.logger.warn('FIREBASE_CREDENTIALS not configured. Push notifications will be simulated.');
    }
  }

  /**
   * Translates a WebSocket event payload to a human-readable title and body,
   * then sends a push notification.
   */
  async sendNotification(userId: string, event: string, payload: any): Promise<boolean> {
    let title = 'New Notification';
    let body = 'You have a new update in Memory.';
    const data: Record<string, string> = { event };

    try {
      switch (event) {
        case 'new_message': {
          const sender = payload.sender ?? 'Someone';
          title = `Message from @${sender}`;
          body = payload.text ?? 'Sent a message.';
          if (payload.id) data.messageId = payload.id;
          break;
        }
        case 'new_circle_request': {
          const requester = payload.requester ?? 'Someone';
          title = 'New Circle Request';
          body = `@${requester} wants to add you to their circle.`;
          if (payload.id) data.membershipId = payload.id;
          break;
        }
        case 'new_circle_milestone': {
          const count = payload.count ?? 0;
          title = 'Circle Milestone Reached!';
          body = `You now have ${count} members in your circle!`;
          break;
        }
        case 'new_memory': {
          const creator = payload.creator ?? 'Someone';
          title = 'New Memory Shared';
          body = `@${creator} posted a new memory!`;
          if (payload.id) data.memoryId = payload.id;
          break;
        }
        case 'new_reaction': {
          const reactor = payload.reactorName ?? 'Someone';
          const emoji = payload.emoji ?? '❤️';
          const caption = payload.memoryCaption ?? '';
          title = 'New Reaction';
          body = `@${reactor} reacted ${emoji} to your memory${caption ? `: "${caption}"` : '.'}`;
          break;
        }
        default:
          this.logger.log(`Using default notification text for event="${event}"`);
      }
    } catch (err) {
      this.logger.error(`Failed to format notification for event="${event}": ${err.message}`);
    }

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
      this.logger.warn(`User with ID="${userId}" not found. Cannot send push notification.`);
      return false;
    }

    if (!user.fcmToken) {
      this.logger.warn(`User @${user.username} has no fcmToken registered. Push notification skipped.`);
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
        this.logger.log(`Successfully sent push notification to @${user.username}: messageId="${response}"`);
        return true;
      } catch (err) {
        this.logger.error(`Error sending push notification to @${user.username}: ${err.message}`);
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
