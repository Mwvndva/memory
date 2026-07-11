import { Injectable, OnApplicationBootstrap } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

@Injectable()
export class JobsService implements OnApplicationBootstrap {
  constructor(
    @InjectQueue('heavy-ops') private readonly heavyOpsQueue: Queue,
  ) {}

  async onApplicationBootstrap() {
    // Register repeatable job to archive old messages daily at midnight
    await this.heavyOpsQueue.add(
      'archive-old-messages',
      {},
      {
        repeat: { pattern: '0 0 * * *' }, // Daily at midnight
        jobId: 'archive-old-messages-daily',
        removeOnComplete: true,
        removeOnFail: true,
      },
    );

    // Global rankings recalculation, hourly. A repeatable job with a fixed
    // jobId is deduplicated cluster-wide by BullMQ, so this runs ONCE across
    // all instances instead of once per instance (was a per-instance
    // setInterval in UsersService).
    await this.heavyOpsQueue.add(
      'recalculate-all-ranks',
      {},
      {
        repeat: { pattern: '0 * * * *' }, // Hourly
        jobId: 'recalculate-all-ranks-hourly',
        removeOnComplete: true,
        removeOnFail: true,
      },
    );

    // Flush Redis reaction counts to Postgres every 15 minutes, cluster-wide
    // (was a per-instance setInterval in RedisService).
    await this.heavyOpsQueue.add(
      'flush-reactions',
      {},
      {
        repeat: { pattern: '*/15 * * * *' }, // Every 15 minutes
        jobId: 'flush-reactions-15m',
        removeOnComplete: true,
        removeOnFail: true,
      },
    );
  }

  async queueStatsRecalculation(userId: string) {
    // Debounce using jobId and a 5-second delay
    await this.heavyOpsQueue.add(
      'recalculate-stats',
      { userId },
      {
        jobId: `recalculate-stats:${userId}`,
        delay: 5000,
        removeOnComplete: true,
        removeOnFail: true,
      },
    );
  }

  async queueNotification(
    userId: string,
    event: string,
    payload: Record<string, unknown>,
  ) {
    await this.heavyOpsQueue.add(
      'send-notification',
      { userId, event, payload },
      {
        attempts: 3,
        backoff: {
          type: 'exponential',
          delay: 1000,
        },
        removeOnComplete: true,
        removeOnFail: true,
      },
    );
  }

  async queueCircleMilestone(userId: string) {
    await this.heavyOpsQueue.add(
      'circle-milestone',
      { userId },
      {
        attempts: 3,
        backoff: {
          type: 'exponential',
          delay: 1000,
        },
        removeOnComplete: true,
        removeOnFail: true,
      },
    );
  }
}
