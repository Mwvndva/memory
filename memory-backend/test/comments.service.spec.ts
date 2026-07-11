import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { CommentsService } from '../src/comments/comments.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { callArg, delegate, MockDelegate } from './prisma-mock';

interface PrismaMock {
  memory: MockDelegate;
  circleMembership: MockDelegate;
  comment: MockDelegate;
}

const VIEWER = 'viewer-1';
const CREATOR = 'creator-1';
const OUTSIDER = 'outsider-1';
const MEMORY_ID = 'memory-1';

const author = {
  id: VIEWER,
  username: 'amara',
  firstName: 'Amara',
  avatarUrl: null,
};

describe('CommentsService', () => {
  let service: CommentsService;
  let prisma: PrismaMock;

  beforeEach(async () => {
    prisma = {
      memory: delegate('findUnique'),
      circleMembership: delegate('findUnique'),
      comment: delegate('findMany', 'create'),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CommentsService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get(CommentsService);
  });

  describe('authorization', () => {
    it('hides a memory the caller has no circle relationship with', async () => {
      prisma.memory.findUnique.mockResolvedValue({
        id: MEMORY_ID,
        creatorId: CREATOR,
        caption: 'c',
      });
      prisma.circleMembership.findUnique.mockResolvedValue(null);

      await expect(service.list(MEMORY_ID, OUTSIDER)).rejects.toBeInstanceOf(
        NotFoundException,
      );
      await expect(
        service.create(MEMORY_ID, OUTSIDER, 'hi'),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(prisma.comment.create).not.toHaveBeenCalled();
    });

    it('hides a memory whose circle request is still pending', async () => {
      prisma.memory.findUnique.mockResolvedValue({
        id: MEMORY_ID,
        creatorId: CREATOR,
        caption: 'c',
      });
      prisma.circleMembership.findUnique.mockResolvedValue({ accepted: false });

      await expect(service.list(MEMORY_ID, VIEWER)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('reports a missing memory the same way as a hidden one', async () => {
      prisma.memory.findUnique.mockResolvedValue(null);

      await expect(service.list(MEMORY_ID, VIEWER)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('lets the creator comment on their own memory without a membership', async () => {
      prisma.memory.findUnique.mockResolvedValue({
        id: MEMORY_ID,
        creatorId: CREATOR,
        caption: 'c',
      });
      prisma.comment.create.mockResolvedValue({
        id: 'c1',
        text: 'mine',
        createdAt: new Date(),
        author,
      });

      await expect(
        service.create(MEMORY_ID, CREATOR, 'mine'),
      ).resolves.toMatchObject({ id: 'c1' });
      expect(prisma.circleMembership.findUnique).not.toHaveBeenCalled();
    });
  });

  describe('create', () => {
    beforeEach(() => {
      prisma.memory.findUnique.mockResolvedValue({
        id: MEMORY_ID,
        creatorId: VIEWER,
        caption: 'c',
      });
    });

    it('strips HTML before persisting', async () => {
      prisma.comment.create.mockResolvedValue({
        id: 'c1',
        text: 'hello',
        createdAt: new Date(),
        author,
      });

      await service.create(MEMORY_ID, VIEWER, '<script>alert(1)</script>hello');

      const args = callArg<{ data: { text: string } }>(prisma.comment.create);
      expect(args.data.text).toBe('hello');
    });

    it('rejects a comment that is empty once sanitized', async () => {
      await expect(
        service.create(MEMORY_ID, VIEWER, '<b></b>   '),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(prisma.comment.create).not.toHaveBeenCalled();
    });

    it('returns the shape the client parses', async () => {
      const createdAt = new Date('2026-07-01T12:00:00.000Z');
      prisma.comment.create.mockResolvedValue({
        id: 'c1',
        text: 'nice',
        createdAt,
        author: { ...author, avatarUrl: 'a.png' },
      });

      const dto = await service.create(MEMORY_ID, VIEWER, 'nice');

      expect(dto).toEqual({
        id: 'c1',
        person: 'Amara',
        text: 'nice',
        created_at: createdAt.toISOString(),
        creator: { id: VIEWER, username: 'amara', avatar_url: 'a.png' },
      });
    });
  });

  describe('list', () => {
    beforeEach(() => {
      prisma.memory.findUnique.mockResolvedValue({
        id: MEMORY_ID,
        creatorId: VIEWER,
        caption: 'c',
      });
    });

    it('returns a nextCursor when a further page exists', async () => {
      const newer = new Date('2026-07-01T12:00:00.000Z');
      const older = new Date('2026-07-01T11:00:00.000Z');
      prisma.comment.findMany.mockResolvedValue([
        { id: 'c1', text: 'a', createdAt: newer, author },
        { id: 'c2', text: 'b', createdAt: older, author },
      ]);

      const result = await service.list(MEMORY_ID, VIEWER, undefined, 1);

      expect(result.comments).toHaveLength(1);
      expect(result.meta.nextCursor).toBe(newer.toISOString());
    });

    it('returns a null cursor on the last page', async () => {
      prisma.comment.findMany.mockResolvedValue([
        { id: 'c1', text: 'a', createdAt: new Date(), author },
      ]);

      const result = await service.list(MEMORY_ID, VIEWER, undefined, 10);
      expect(result.meta.nextCursor).toBeNull();
    });

    it('falls back to the username when the author has no first name', async () => {
      prisma.comment.findMany.mockResolvedValue([
        {
          id: 'c1',
          text: 'a',
          createdAt: new Date(),
          author: { ...author, firstName: '' },
        },
      ]);

      const result = await service.list(MEMORY_ID, VIEWER);
      expect(result.comments[0].person).toBe('amara');
    });
  });
});
