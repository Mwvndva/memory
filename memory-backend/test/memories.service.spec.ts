import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { MemoriesService } from '../src/memories/memories.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { RedisService } from '../src/redis/redis.service';
import { callArg, delegate, MockDelegate } from './prisma-mock';

interface PrismaMock {
  memory: MockDelegate;
}
interface RedisMock {
  cacheDel: jest.Mock;
  clearReactions: jest.Mock;
}
import { AppGateway } from '../src/gateway/app.gateway';
import { UsersService } from '../src/users/users.service';
import { JobsService } from '../src/jobs/jobs.service';

const OWNER = 'owner-1';
const STRANGER = 'stranger-2';
const MEMORY_ID = 'memory-1';

describe('MemoriesService — caption edits and deletion', () => {
  let service: MemoriesService;
  let prismaMock: PrismaMock;
  let redisMock: RedisMock;

  beforeEach(async () => {
    prismaMock = {
      memory: delegate('findUnique', 'update', 'delete'),
    };

    redisMock = {
      cacheDel: jest.fn().mockResolvedValue(undefined),
      clearReactions: jest.fn().mockResolvedValue(undefined),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MemoriesService,
        { provide: PrismaService, useValue: prismaMock },
        { provide: RedisService, useValue: redisMock },
        { provide: AppGateway, useValue: { sendToUser: jest.fn() } },
        { provide: UsersService, useValue: {} },
        {
          provide: JobsService,
          useValue: {
            queueNotification: jest.fn(),
            queueStatsRecalculation: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get(MemoriesService);
  });

  describe('updateCaption', () => {
    it('rejects a caption edit from someone who does not own the memory', async () => {
      prismaMock.memory.findUnique.mockResolvedValue({
        id: MEMORY_ID,
        creatorId: OWNER,
      });

      await expect(
        service.updateCaption(MEMORY_ID, STRANGER, 'hijacked'),
      ).rejects.toBeInstanceOf(ForbiddenException);

      expect(prismaMock.memory.update).not.toHaveBeenCalled();
    });

    it('raises NotFound when the memory does not exist', async () => {
      prismaMock.memory.findUnique.mockResolvedValue(null);

      await expect(
        service.updateCaption(MEMORY_ID, OWNER, 'anything'),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('strips HTML from the caption before persisting it', async () => {
      prismaMock.memory.findUnique.mockResolvedValue({
        id: MEMORY_ID,
        creatorId: OWNER,
      });
      prismaMock.memory.update.mockResolvedValue({ id: MEMORY_ID });

      await service.updateCaption(
        MEMORY_ID,
        OWNER,
        '<script>alert(1)</script>hello',
      );

      const args = callArg<{ data: { caption: string } }>(
        prismaMock.memory.update,
      );
      expect(args.data.caption).toBe('hello');
      expect(redisMock.cacheDel).toHaveBeenCalledWith(`memory:${MEMORY_ID}`);
    });
  });

  describe('remove', () => {
    it('rejects deletion by a non-owner and leaves the record intact', async () => {
      prismaMock.memory.findUnique.mockResolvedValue({
        id: MEMORY_ID,
        creatorId: OWNER,
      });

      await expect(service.remove(MEMORY_ID, STRANGER)).rejects.toBeInstanceOf(
        ForbiddenException,
      );

      expect(prismaMock.memory.delete).not.toHaveBeenCalled();
      expect(redisMock.clearReactions).not.toHaveBeenCalled();
    });

    it('deletes the memory and drops its reaction counters for the owner', async () => {
      prismaMock.memory.findUnique.mockResolvedValue({
        id: MEMORY_ID,
        creatorId: OWNER,
      });
      prismaMock.memory.delete.mockResolvedValue({ id: MEMORY_ID });

      await expect(service.remove(MEMORY_ID, OWNER)).resolves.toEqual({
        id: MEMORY_ID,
        deleted: true,
      });

      expect(prismaMock.memory.delete).toHaveBeenCalledWith({
        where: { id: MEMORY_ID },
      });
      expect(redisMock.clearReactions).toHaveBeenCalledWith(MEMORY_ID);
      expect(redisMock.cacheDel).toHaveBeenCalledWith(`memory:${MEMORY_ID}`);
    });
  });
});
