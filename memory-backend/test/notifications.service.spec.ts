import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { NotificationsService } from '../src/notifications/notifications.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { callArg, delegate, MockDelegate } from './prisma-mock';

interface PrismaMock {
  notification: MockDelegate;
}

const OWNER = 'user-1';
const STRANGER = 'user-2';

function row(id: string, createdAt: Date, isRead = false) {
  return {
    id,
    title: 'New Reaction',
    body: '@amara reacted 🔥 to your memory',
    createdAt,
    isRead,
    type: 'reaction',
    data: JSON.stringify({ event: 'new_reaction', memoryId: 'm-1' }),
  };
}

describe('NotificationsService', () => {
  let service: NotificationsService;
  let prisma: PrismaMock;

  beforeEach(async () => {
    prisma = {
      notification: delegate(
        'create',
        'findMany',
        'findUnique',
        'update',
        'updateMany',
        'count',
      ),
    };
    prisma.notification.count.mockResolvedValue(0);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        NotificationsService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get(NotificationsService);
  });

  describe('record', () => {
    it('persists title, body and type derived from the event payload', async () => {
      prisma.notification.create.mockResolvedValue({});

      await service.record(OWNER, 'new_circle_request', {
        senderId: 'u-9',
        senderUsername: 'amara',
      });

      const args = callArg<{
        data: { userId: string; type: string; body: string; data: string };
      }>(prisma.notification.create);
      expect(args.data.userId).toBe(OWNER);
      expect(args.data.type).toBe('circleRequest');
      expect(args.data.body).toBe('@amara wants to add you to their circle.');
      expect(
        (JSON.parse(args.data.data) as { senderId: string }).senderId,
      ).toBe('u-9');
    });

    it('never throws — a failed history write must not break delivery', async () => {
      prisma.notification.create.mockRejectedValue(new Error('db down'));

      await expect(
        service.record(OWNER, 'new_message', { sender: 'amara' }),
      ).resolves.toBeUndefined();
    });
  });

  describe('list', () => {
    it('returns a page, the unread count, and a cursor when more remain', async () => {
      const now = new Date('2026-07-01T12:00:00.000Z');
      const older = new Date('2026-07-01T11:00:00.000Z');
      // take+1 rows signals a further page
      prisma.notification.findMany.mockResolvedValue([
        row('n1', now),
        row('n2', older),
      ]);
      prisma.notification.count.mockResolvedValue(7);

      const result = await service.list(OWNER, undefined, 1);

      expect(result.data).toHaveLength(1);
      expect(result.data[0].id).toBe('n1');
      expect(result.data[0].timestamp).toBe(now.toISOString());
      expect(result.data[0].data).toEqual({
        event: 'new_reaction',
        memoryId: 'm-1',
      });
      expect(result.nextCursor).toBe(now.toISOString());
      expect(result.unreadCount).toBe(7);
    });

    it('returns a null cursor on the last page', async () => {
      prisma.notification.findMany.mockResolvedValue([
        row('n1', new Date('2026-07-01T12:00:00.000Z')),
      ]);

      const result = await service.list(OWNER, undefined, 20);

      expect(result.data).toHaveLength(1);
      expect(result.nextCursor).toBeNull();
    });

    it('applies the cursor as a createdAt upper bound', async () => {
      prisma.notification.findMany.mockResolvedValue([]);

      await service.list(OWNER, '2026-07-01T12:00:00.000Z', 20);

      const args = callArg<{ where: { createdAt: { lt: Date } } }>(
        prisma.notification.findMany,
      );
      expect(args.where.createdAt.lt).toEqual(
        new Date('2026-07-01T12:00:00.000Z'),
      );
    });

    it('ignores an unparseable cursor rather than querying on NaN', async () => {
      prisma.notification.findMany.mockResolvedValue([]);

      await service.list(OWNER, 'not-a-date', 20);

      const args = callArg<{ where: { createdAt?: unknown } }>(
        prisma.notification.findMany,
      );
      expect(args.where.createdAt).toBeUndefined();
    });

    it('caps the page size', async () => {
      prisma.notification.findMany.mockResolvedValue([]);

      await service.list(OWNER, undefined, 5000);

      const args = callArg<{ take: number }>(prisma.notification.findMany);
      expect(args.take).toBe(51); // 50 + 1
    });

    it('survives a row whose data column is not valid JSON', async () => {
      const bad = row('n1', new Date());
      bad.data = 'not json';
      prisma.notification.findMany.mockResolvedValue([bad]);

      const result = await service.list(OWNER, undefined, 20);
      expect(result.data[0].data).toEqual({});
    });
  });

  describe('markRead', () => {
    it('refuses to mark another user notification as read', async () => {
      prisma.notification.findUnique.mockResolvedValue({
        id: 'n1',
        userId: OWNER,
      });

      await expect(service.markRead(STRANGER, 'n1')).rejects.toBeInstanceOf(
        ForbiddenException,
      );
      expect(prisma.notification.update).not.toHaveBeenCalled();
    });

    it('raises NotFound for a missing notification', async () => {
      prisma.notification.findUnique.mockResolvedValue(null);

      await expect(service.markRead(OWNER, 'n1')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('marks the owner own notification read', async () => {
      prisma.notification.findUnique.mockResolvedValue({
        id: 'n1',
        userId: OWNER,
      });
      prisma.notification.update.mockResolvedValue({});

      await expect(service.markRead(OWNER, 'n1')).resolves.toEqual({
        id: 'n1',
        isRead: true,
      });
    });
  });

  describe('markAllRead', () => {
    it('only touches the caller unread rows', async () => {
      prisma.notification.updateMany.mockResolvedValue({ count: 4 });

      await expect(service.markAllRead(OWNER)).resolves.toEqual({ updated: 4 });

      expect(prisma.notification.updateMany).toHaveBeenCalledWith({
        where: { userId: OWNER, isRead: false },
        data: { isRead: true },
      });
    });
  });
});
