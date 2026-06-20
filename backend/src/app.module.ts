import { Module, NestModule, MiddlewareConsumer } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma/prisma.module';
import { RedisModule } from './redis/redis.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { MemoriesModule } from './memories/memories.module';
import { CirclesModule } from './circles/circles.module';
import { MessagesModule } from './messages/messages.module';
import { GatewayModule } from './gateway/gateway.module';
import { StorageModule } from './storage/storage.module';
import { LoggingMiddleware } from './logging.middleware';

@Module({
  imports: [
    // ── Core infrastructure (global) ──────────────────────
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,   // @Global — PrismaService available everywhere
    RedisModule,    // @Global — RedisService available everywhere
    StorageModule,  // @Global — StorageService available everywhere

    // ── Feature modules ───────────────────────────────────
    AuthModule,
    UsersModule,
    MemoriesModule,
    CirclesModule,
    MessagesModule,
    GatewayModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(LoggingMiddleware).forRoutes('*');
  }
}
