import { Test, TestingModule } from '@nestjs/testing';
import { HeavyOpsProcessor } from '../src/jobs/heavy-ops.processor';
import { UsersService } from '../src/users/users.service';
import { CirclesService } from '../src/circles/circles.service';
import { AppGateway } from '../src/gateway/app.gateway';
import { PrismaService } from '../src/prisma/prisma.service';
import { StorageService } from '../src/storage/storage.service';
import { RedisService } from '../src/redis/redis.service';
import { PushNotificationService } from '../src/notifications/push-notification.service';

describe('Message Archival Job', () => {
  let processor: HeavyOpsProcessor;
  let prismaMock: any;
  let storageMock: any;

  beforeEach(async () => {
    prismaMock = {
      message: {
        findMany: jest.fn(),
        deleteMany: jest.fn(),
      },
    };

    storageMock = {
      uploadFile: jest.fn().mockResolvedValue('http://mock-storage.local/archive.json'),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        HeavyOpsProcessor,
        { provide: UsersService, useValue: {} },
        { provide: CirclesService, useValue: {} },
        { provide: AppGateway, useValue: {} },
        { provide: PrismaService, useValue: prismaMock },
        { provide: StorageService, useValue: storageMock },
        { provide: RedisService, useValue: {} },
        { provide: PushNotificationService, useValue: {} },
      ],
    }).compile();

    processor = module.get<HeavyOpsProcessor>(HeavyOpsProcessor);
  });

  it('should exit early if no messages are older than 90 days', async () => {
    prismaMock.message.findMany.mockResolvedValue([]);

    await processor.archiveOldMessages();

    expect(prismaMock.message.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          timestamp: { lt: expect.any(Date) },
        },
        take: 2000,
        orderBy: { timestamp: 'asc' },
      })
    );
    expect(storageMock.uploadFile).not.toHaveBeenCalled();
    expect(prismaMock.message.deleteMany).not.toHaveBeenCalled();
  });

  it('should group, upload, and delete messages older than 90 days', async () => {
    const mockMessages = [
      {
        id: 'msg-1',
        senderId: 'user-a',
        receiverId: 'user-b',
        text: 'hello',
        timestamp: new Date('2026-01-15T10:00:00Z'),
      },
      {
        id: 'msg-2',
        senderId: 'user-b',
        receiverId: 'user-a',
        text: 'world',
        timestamp: new Date('2026-01-20T11:00:00Z'),
      },
      {
        id: 'msg-3',
        senderId: 'user-a',
        receiverId: 'user-b',
        text: 'nest',
        timestamp: new Date('2026-02-10T12:00:00Z'),
      },
    ];

    prismaMock.message.findMany.mockResolvedValue(mockMessages);
    prismaMock.message.deleteMany.mockResolvedValue({ count: mockMessages.length });

    await processor.archiveOldMessages();

    // 1. Should query for old messages
    expect(prismaMock.message.findMany).toHaveBeenCalled();

    // 2. Should group by month (2026-01 and 2026-02) and upload twice
    expect(storageMock.uploadFile).toHaveBeenCalledTimes(2);

    // Verify first group upload (2026-01)
    expect(storageMock.uploadFile).toHaveBeenCalledWith(
      expect.objectContaining({
        originalname: expect.stringContaining('archive-2026-01-'),
        mimetype: 'application/json',
        buffer: expect.any(Buffer),
      }),
      'archives/messages'
    );

    // Verify second group upload (2026-02)
    expect(storageMock.uploadFile).toHaveBeenCalledWith(
      expect.objectContaining({
        originalname: expect.stringContaining('archive-2026-02-'),
        mimetype: 'application/json',
        buffer: expect.any(Buffer),
      }),
      'archives/messages'
    );

    // 3. Should delete archived messages from the database
    expect(prismaMock.message.deleteMany).toHaveBeenCalledTimes(2);
    expect(prismaMock.message.deleteMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          timestamp: { lt: expect.any(Date) },
          id: { in: ['msg-1', 'msg-2'] },
        },
      })
    );
    expect(prismaMock.message.deleteMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          timestamp: { lt: expect.any(Date) },
          id: { in: ['msg-3'] },
        },
      })
    );
  });
});
