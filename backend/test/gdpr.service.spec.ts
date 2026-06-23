import { Test, TestingModule } from '@nestjs/testing';
import { UsersService } from '../src/users/users.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { NotFoundException } from '@nestjs/common';

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

describe('UsersService - GDPR Compliance Controls', () => {
  let service: UsersService;
  let prismaMock: any;

  beforeEach(async () => {
    prismaMock = {
      user: {
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      memory: {
        updateMany: jest.fn(),
      },
      message: {
        updateMany: jest.fn(),
      },
      circleMembership: {
        updateMany: jest.fn(),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: PrismaService, useValue: prismaMock },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
  });

  describe('deleteAccount (GDPR Right to Erasure)', () => {
    it('should throw NotFoundException if user does not exist', async () => {
      prismaMock.user.findUnique.mockResolvedValue(null);

      await expect(service.deleteAccount('non-existent-id')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should anonymize profile fields and soft-delete associated relations', async () => {
      const mockUser = {
        id: 'user-123',
        firstName: 'Alice',
        lastName: 'Smith',
        username: 'alice',
        email: 'alice@example.com',
        phone: '+254712345678',
      };

      prismaMock.user.findUnique.mockResolvedValue(mockUser);
      prismaMock.user.update.mockResolvedValue({ id: 'user-123' });
      prismaMock.memory.updateMany.mockResolvedValue({ count: 1 });
      prismaMock.message.updateMany.mockResolvedValue({ count: 1 });
      prismaMock.circleMembership.updateMany.mockResolvedValue({ count: 1 });

      const result = await service.deleteAccount('user-123');

      expect(result.success).toBe(true);
      
      // Verify User record is anonymized & soft deleted
      expect(prismaMock.user.update).toHaveBeenCalledWith({
        where: { id: 'user-123' },
        data: expect.objectContaining({
          firstName: 'Deleted',
          lastName: 'User',
          username: expect.stringContaining('deleted_'),
          email: expect.stringContaining('@erasure.example.com'),
          phone: 'deleted-user-123',
          phoneNormalized: 'deleted-user-123',
          avatarUrl: null,
          deletedAt: expect.any(Date),
        }),
      });

      // Verify associated memories, messages, and circle memberships are soft-deleted
      expect(prismaMock.memory.updateMany).toHaveBeenCalledWith({
        where: { creatorId: 'user-123', deletedAt: null },
        data: { deletedAt: expect.any(Date) },
      });
      expect(prismaMock.message.updateMany).toHaveBeenCalledWith({
        where: {
          OR: [{ senderId: 'user-123' }, { receiverId: 'user-123' }],
          deletedAt: null,
        },
        data: { deletedAt: expect.any(Date) },
      });
      expect(prismaMock.circleMembership.updateMany).toHaveBeenCalledWith({
        where: {
          OR: [{ userId: 'user-123' }, { memberId: 'user-123' }],
          deletedAt: null,
        },
        data: { deletedAt: expect.any(Date) },
      });
    });
  });

  describe('exportUserData (GDPR Right to Data Portability)', () => {
    it('should throw NotFoundException if user does not exist', async () => {
      prismaMock.user.findUnique.mockResolvedValue(null);

      await expect(service.exportUserData('non-existent-id')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should retrieve all personal records and return a structured portability JSON', async () => {
      const mockFullUser = {
        id: 'user-123',
        firstName: 'Alice',
        lastName: 'Smith',
        username: 'alice',
        email: 'alice@example.com',
        phone: '+254712345678',
        createdAt: new Date(),
        memories: [
          {
            id: 'memory-1',
            caption: 'Weekend trip',
            videoUrl: 'trip.mp4',
            gradientColors: ['#FF0000', '#0000FF'],
            createdAt: new Date(),
          },
        ],
        sentMessages: [
          {
            id: 'msg-1',
            receiverId: 'user-456',
            text: 'Hello!',
            timestamp: new Date(),
          },
        ],
        receivedMessages: [
          {
            id: 'msg-2',
            senderId: 'user-456',
            text: 'Hey there',
            timestamp: new Date(),
          },
        ],
        userMemberships: [
          {
            id: 'membership-1',
            memberId: 'user-456',
            accepted: true,
            createdAt: new Date(),
          },
        ],
      };

      prismaMock.user.findUnique.mockResolvedValue(mockFullUser);

      const exported = await service.exportUserData('user-123');

      expect(exported.profile.email).toBe('alice@example.com');
      expect(exported.memories).toHaveLength(1);
      expect(exported.memories[0].caption).toBe('Weekend trip');
      expect(exported.sentMessages).toHaveLength(1);
      expect(exported.receivedMessages).toHaveLength(1);
      expect(exported.circleMemberships).toHaveLength(1);
    });
  });
});
