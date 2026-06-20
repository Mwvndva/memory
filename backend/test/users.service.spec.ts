import { Test, TestingModule } from '@nestjs/testing';
import { UsersService } from '../src/users/users.service';
import { PrismaService } from '../src/prisma/prisma.service';

describe('UsersService.findByPhones (PII & Scan Leak Baseline)', () => {
  let service: UsersService;
  let prismaMock: any;

  beforeEach(async () => {
    prismaMock = {
      user: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'user-1',
            username: 'alice',
            firstName: 'Alice',
            lastName: 'Smith',
            phone: '+254712345678',
            avatarUrl: null,
          },
          {
            id: 'user-2',
            username: 'bob',
            firstName: 'Bob',
            lastName: 'Jones',
            phone: '+254787654321',
            avatarUrl: 'bob.jpg',
          },
        ]),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: PrismaService, useValue: prismaMock },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
    (service as any).prisma = prismaMock; // inject mock explicitly
  });

  it('should full-table-scan by calling findMany without where filter and leak raw phone numbers', async () => {
    const inputPhones = ['0712345678'];
    const matched = await service.findByPhones(inputPhones);

    // 1. Assert full-table scan: findMany was called with select, but NO where clause
    expect(prismaMock.user.findMany).toHaveBeenCalledWith(
      expect.not.objectContaining({
        where: expect.any(Object),
      })
    );

    // 2. Assert finding matches Alice (by last 9 digits suffix match)
    expect(matched.length).toBe(1);
    expect(matched[0].username).toBe('alice');

    // 3. Assert PII Leakage: the matched user object contains the raw phone field
    expect(matched[0]).toHaveProperty('phone');
    expect(matched[0].phone).toBe('+254712345678');
  });
});
