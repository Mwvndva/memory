import { Test, TestingModule } from '@nestjs/testing';
import { UsersService } from '../src/users/users.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { RedisService } from '../src/redis/redis.service';
import { normalizePhone } from '../src/users/users.service';
import { MockDelegate } from './prisma-mock';

interface PrismaMock {
  user: MockDelegate;
}

interface FindManyArgs {
  where?: { phoneNormalized?: { in?: string[] } };
}

describe('UsersService.findByPhones (Optimized Contact Sync)', () => {
  let service: UsersService;
  let prismaMock: PrismaMock;

  beforeEach(async () => {
    prismaMock = {
      user: {
        findMany: jest.fn().mockImplementation((args: FindManyArgs) => {
          const inArray: string[] = args?.where?.phoneNormalized?.in ?? [];
          const allUsers = [
            {
              id: 'user-1',
              username: 'alice',
              firstName: 'Alice',
              lastName: 'Smith',
              phone: '+254712345678',
              phoneNormalized: '+254712345678',
              avatarUrl: null,
            },
            {
              id: 'user-2',
              username: 'bob',
              firstName: 'Bob',
              lastName: 'Jones',
              phone: '+254787654321',
              phoneNormalized: '+254787654321',
              avatarUrl: 'bob.jpg',
            },
          ];
          return Promise.resolve(
            allUsers.filter((u) => inArray.includes(u.phoneNormalized)),
          );
        }),
      },
    };

    // UsersService caches profile reads through Redis; a null-returning cache
    // keeps every lookup falling through to the Prisma mock above.
    const redisMock = {
      cacheGetJson: jest.fn().mockResolvedValue(null),
      cacheSetJson: jest.fn().mockResolvedValue(undefined),
      cacheDel: jest.fn().mockResolvedValue(undefined),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: PrismaService, useValue: prismaMock },
        { provide: RedisService, useValue: redisMock },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
    (service as unknown as { prisma: PrismaMock }).prisma = prismaMock; // inject mock explicitly
  });

  it('should query the database using indexed phoneNormalized lookups', async () => {
    const inputPhones = ['0712345678'];
    const matched = await service.findByPhones(inputPhones);

    // 1. Assert index-friendly lookup: findMany was called with where clause on phoneNormalized
    expect(prismaMock.user.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          phoneNormalized: {
            in: ['+254712345678'],
          },
        },
      }),
    );

    // 2. Assert finding matches Alice (by last 9 digits suffix match)
    expect(matched.length).toBe(1);
    expect(matched[0].username).toBe('alice');

    // 3. Assert the matched user object contains the phone field
    expect(matched[0]).toHaveProperty('phone');
    expect(matched[0].phone).toBe('+254712345678');
  });

  describe('normalizePhone helper', () => {
    it('should format clean E.164 format correctly', () => {
      expect(normalizePhone('+254712345678')).toBe('+254712345678');
      expect(normalizePhone('+15551234567')).toBe('+15551234567');
    });

    it('should normalize local Kenyan numbers using KE fallback', () => {
      expect(normalizePhone('0712345678')).toBe('+254712345678');
      expect(normalizePhone('712345678')).toBe('+254712345678');
    });

    it('should normalize local US numbers using US fallback', () => {
      // libphonenumber-js US numbers are 10 digits
      expect(normalizePhone('2025550143')).toBe('+12025550143');
      expect(normalizePhone('(202) 555-0143')).toBe('+12025550143');
    });

    it('should fallback to extracting digits if invalid or unparseable', () => {
      expect(normalizePhone('123')).toBe('123');
      expect(normalizePhone('+123')).toBe('+123');
      expect(normalizePhone('')).toBe('');
    });
  });
});
