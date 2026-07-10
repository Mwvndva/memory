import { Module, NestModule, MiddlewareConsumer } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma/prisma.module';
import { RedisModule } from './redis/redis.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { MemoriesModule } from './memories/memories.module';
import { CommentsModule } from './comments/comments.module';
import { NotificationsModule } from './notifications/notifications.module';
import { CirclesModule } from './circles/circles.module';
import { MessagesModule } from './messages/messages.module';
import { GatewayModule } from './gateway/gateway.module';
import { StorageModule } from './storage/storage.module';
import { LoggingMiddleware } from './logging.middleware';
import { BullModule } from '@nestjs/bullmq';
import { JobsModule } from './jobs/jobs.module';
import { HealthModule } from './health/health.module';
import { LoggerModule } from 'nestjs-pino';
import { PrometheusModule } from '@willsoto/nestjs-prometheus';
import { APP_FILTER } from '@nestjs/core';
import { SentryGlobalFilter } from '@sentry/nestjs/setup';

@Module({
  imports: [
    // ── Core infrastructure (global) ──────────────────────
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule, // @Global — PrismaService available everywhere
    RedisModule, // @Global — RedisService available everywhere
    StorageModule, // @Global — StorageService available everywhere
    BullModule.forRoot({
      connection: {
        url: process.env.REDIS_URL || 'redis://localhost:6379',
      },
    }),
    JobsModule,

    LoggerModule.forRoot({
      pinoHttp: {
        autoLogging: false, // Disable automatic request logging to avoid duplication with LoggingMiddleware
        transport:
          process.env.NODE_ENV !== 'production'
            ? { target: 'pino-pretty' }
            : undefined,
      },
    }),

    PrometheusModule.register({
      defaultMetrics: {
        enabled: true,
      },
    }),

    // ── Feature modules ───────────────────────────────────
    AuthModule,
    UsersModule,
    MemoriesModule,
    CommentsModule,
    CirclesModule,
    MessagesModule,
    NotificationsModule,
    GatewayModule,
    HealthModule,
  ],
  controllers: [AppController],
  providers: [
    AppService,
    {
      provide: APP_FILTER,
      useClass: SentryGlobalFilter,
    },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(LoggingMiddleware).forRoutes('*');
  }
}
