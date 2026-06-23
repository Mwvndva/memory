import { Test, TestingModule } from '@nestjs/testing';
import { HeavyOpsProcessor } from '../src/jobs/heavy-ops.processor';
import { AppGateway } from '../src/gateway/app.gateway';
import { RedisService } from '../src/redis/redis.service';
import { PushNotificationService } from '../src/notifications/push-notification.service';
import { UsersService } from '../src/users/users.service';
import { CirclesService } from '../src/circles/circles.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { StorageService } from '../src/storage/storage.service';
import { MessagesService } from '../src/messages/messages.service';

// Mock pg to prevent real connection attempts during tests
jest.mock('pg', () => {
  const actualPg = jest.requireActual('pg');
  return {
    ...actualPg,
    Pool: jest.fn().mockImplementation(() => {
      return {
        connect: jest.fn(),
        query: jest.fn(),
        end: jest.fn(),
      };
    }),
  };
});

describe('Push Notification & Offline Fallback', () => {
  let processor: HeavyOpsProcessor;
  let gateway: AppGateway;
  let redisService: RedisService;
  let pushNotificationService: PushNotificationService;

  const mockRedisService = {
    getSocketId: jest.fn(),
    getClient: jest.fn().mockReturnValue({
      publish: jest.fn(),
    }),
  };

  const mockPushNotificationService = {
    sendNotification: jest.fn().mockResolvedValue(true),
  };

  const mockAppGateway = {
    sendToUser: jest.fn().mockResolvedValue(undefined),
    _send: jest.fn(),
  };

  const mockPrismaService = {
    user: {
      findUnique: jest.fn(),
    },
    circleMembership: {
      findUnique: jest.fn(),
    },
    message: {
      create: jest.fn(),
    },
  };

  const mockMessagesService = {
    create: jest.fn(),
  };

  beforeEach(async () => {
    // Stub $connect and $disconnect to avoid network/database dependency
    jest.spyOn(PrismaService.prototype, '$connect').mockResolvedValue(undefined);
    jest.spyOn(PrismaService.prototype, '$disconnect').mockResolvedValue(undefined);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        HeavyOpsProcessor,
        { provide: AppGateway, useValue: mockAppGateway },
        { provide: RedisService, useValue: mockRedisService },
        { provide: PushNotificationService, useValue: mockPushNotificationService },
        { provide: UsersService, useValue: {} },
        { provide: CirclesService, useValue: {} },
        { provide: PrismaService, useValue: mockPrismaService },
        { provide: StorageService, useValue: {} },
        { provide: MessagesService, useValue: mockMessagesService },
      ],
    }).compile();

    processor = module.get<HeavyOpsProcessor>(HeavyOpsProcessor);
    gateway = module.get<AppGateway>(AppGateway);
    redisService = module.get<RedisService>(RedisService);
    pushNotificationService = module.get<PushNotificationService>(PushNotificationService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('HeavyOpsProcessor - send-notification job', () => {
    it('should send via WebSocket gateway if recipient is online', async () => {
      const mockJob: any = {
        name: 'send-notification',
        data: {
          userId: 'user-123',
          event: 'new_memory',
          payload: { id: 'memory-1' },
        },
      };

      mockRedisService.getSocketId.mockResolvedValue('socket-abc');

      await processor.process(mockJob);

      expect(mockRedisService.getSocketId).toHaveBeenCalledWith('user-123');
      expect(mockAppGateway.sendToUser).toHaveBeenCalledWith(
        'user-123',
        'new_memory',
        mockJob.data.payload,
      );
      expect(mockPushNotificationService.sendNotification).not.toHaveBeenCalled();
    });

    it('should fall back to FCM push notification if recipient is offline', async () => {
      const mockJob: any = {
        name: 'send-notification',
        data: {
          userId: 'user-123',
          event: 'new_memory',
          payload: { id: 'memory-1' },
        },
      };

      mockRedisService.getSocketId.mockResolvedValue(null);

      await processor.process(mockJob);

      expect(mockRedisService.getSocketId).toHaveBeenCalledWith('user-123');
      expect(mockAppGateway.sendToUser).not.toHaveBeenCalled();
      expect(mockPushNotificationService.sendNotification).toHaveBeenCalledWith(
        'user-123',
        'new_memory',
        mockJob.data.payload,
      );
    });
  });
});
