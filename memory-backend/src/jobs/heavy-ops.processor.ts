import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { Injectable, Logger, Inject, forwardRef } from '@nestjs/common';
import { UsersService } from '../users/users.service';
import { CirclesService } from '../circles/circles.service';
import { AppGateway } from '../gateway/app.gateway';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { RedisService } from '../redis/redis.service';
import { PushNotificationService } from '../notifications/push-notification.service';
import { NotificationsService } from '../notifications/notifications.service';

/**
 * Union of every payload enqueued onto the `heavy-ops` queue. Fields are
 * optional because a single Job type covers all job names.
 */
export interface HeavyOpsJobData {
  userId?: string;
  event?: string;
  payload?: Record<string, unknown>;
}

@Processor('heavy-ops')
@Injectable()
export class HeavyOpsProcessor extends WorkerHost {
  private readonly logger = new Logger(HeavyOpsProcessor.name);

  constructor(
    private readonly usersService: UsersService,
    @Inject(forwardRef(() => CirclesService))
    private readonly circlesService: CirclesService,
    private readonly gateway: AppGateway,
    private readonly prisma: PrismaService,
    private readonly storageService: StorageService,
    private readonly redisService: RedisService,
    private readonly pushNotificationService: PushNotificationService,
    private readonly notificationsService: NotificationsService,
  ) {
    super();
  }

  async process(job: Job<HeavyOpsJobData, unknown, string>): Promise<void> {
    this.logger.log(`Processing job ID=${job.id} type=${job.name}`);

    switch (job.name) {
      case 'recalculate-stats': {
        const { userId } = job.data;
        if (!userId) break;
        await this.usersService.recalculateUserStats(userId);
        break;
      }
      case 'send-notification': {
        const { userId, event, payload } = job.data;
        if (!userId || !event) break;
        const data = payload ?? {};

        // Recorded regardless of delivery channel: the history screen must show
        // the same events whether the user was online or offline at the time.
        await this.notificationsService.record(userId, event, data);

        const socketId = await this.redisService.getSocketId(userId);
        if (socketId) {
          this.logger.log(
            `User userId="${userId}" is online. Sending real-time WebSocket notification.`,
          );
          await this.gateway.sendToUser(userId, event, data);
        } else {
          this.logger.log(
            `User userId="${userId}" is offline. Falling back to FCM push notification.`,
          );
          await this.pushNotificationService.sendNotification(
            userId,
            event,
            data,
          );
        }
        break;
      }
      case 'circle-milestone': {
        const { userId } = job.data;
        if (!userId) break;
        await this.circlesService.checkAndBroadcastCircleMilestone(userId);
        break;
      }
      case 'archive-old-messages': {
        await this.archiveOldMessages();
        break;
      }
      case 'recalculate-all-ranks': {
        await this.usersService.recalculateAllUserRanks();
        break;
      }
      case 'flush-reactions': {
        await this.redisService.flushReactionsToDb();
        break;
      }
      default:
        this.logger.warn(`Unknown job type: ${job.name}`);
    }
  }

  async archiveOldMessages() {
    this.logger.log('[Archival Job] Starting message archival process...');
    const cutoffDate = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000); // 90 days ago

    // Fetch messages older than 90 days.
    // Fetch in batches (e.g. up to 2000) to keep memory footprint bounded.
    const messages = await this.prisma.message.findMany({
      where: {
        timestamp: { lt: cutoffDate },
      },
      take: 2000,
      orderBy: { timestamp: 'asc' },
    });

    if (messages.length === 0) {
      this.logger.log(
        '[Archival Job] No messages older than 90 days to archive.',
      );
      return;
    }

    this.logger.log(
      `[Archival Job] Found ${messages.length} messages to archive.`,
    );

    // Group messages by year-month (e.g., "YYYY-MM")
    const groups: Record<string, typeof messages> = {};
    for (const msg of messages) {
      const ym = msg.timestamp.toISOString().slice(0, 7); // YYYY-MM
      if (!groups[ym]) groups[ym] = [];
      groups[ym].push(msg);
    }

    // Process each group and upload to cold storage
    for (const [ym, groupMessages] of Object.entries(groups)) {
      const archiveContent = JSON.stringify(groupMessages, null, 2);
      const buffer = Buffer.from(archiveContent, 'utf-8');

      // Create a mock Express.Multer.File object for the StorageService uploadFile method
      const dateStr = new Date().toISOString().slice(0, 10);
      const filename = `archive-${ym}-${dateStr}-${Date.now()}.json`;

      // StorageService only reads these fields off the uploaded file.
      const archiveFile = {
        fieldname: 'file',
        originalname: filename,
        encoding: '7bit',
        mimetype: 'application/json',
        buffer,
        size: buffer.length,
      } as Express.Multer.File;

      this.logger.log(
        `[Archival Job] Uploading group "${ym}" (${groupMessages.length} messages) to cold storage...`,
      );
      const fileUrl = await this.storageService.uploadFile(
        archiveFile,
        'archives/messages',
      );
      this.logger.log(
        `[Archival Job] Archive uploaded successfully to URL="${fileUrl}"`,
      );

      // Delete the archived messages from the database
      const ids = groupMessages.map((m) => m.id);
      this.logger.log(
        `[Archival Job] Deleting ${ids.length} archived messages from database...`,
      );
      // Delete using composite primary key pattern (timestamp < cutoff and id in list)
      const result = await this.prisma.message.deleteMany({
        where: {
          timestamp: { lt: cutoffDate },
          id: { in: ids },
        },
      });
      this.logger.log(
        `[Archival Job] Deleted ${result.count} messages from database.`,
      );
    }

    this.logger.log('[Archival Job] Message archival process completed.');
  }
}
