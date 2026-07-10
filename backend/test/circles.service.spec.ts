import { Test, TestingModule } from '@nestjs/testing';
import { CirclesService } from '../src/circles/circles.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { AppGateway } from '../src/gateway/app.gateway';
import { JobsService } from '../src/jobs/jobs.service';
import { delegate, MockDelegate } from './prisma-mock';

interface PrismaMock {
  circleMembership: MockDelegate;
  user: MockDelegate;
  $transaction: jest.Mock;
}

describe('CirclesService', () => {
  let service: CirclesService;
  let prisma: PrismaMock;

  beforeEach(async () => {
    const prismaMock: PrismaMock = {
      circleMembership: delegate('findFirst', 'update', 'create'),
      user: delegate('findUnique'),
      $transaction: jest.fn(),
    };
    // acceptRequest() wraps its writes in an interactive transaction; hand the
    // callback the same mock so the assertions below observe the calls.
    prismaMock.$transaction.mockImplementation(
      (cb: (tx: PrismaMock) => unknown) => cb(prismaMock),
    );
    prisma = prismaMock;

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CirclesService,
        { provide: PrismaService, useValue: prismaMock },
        { provide: AppGateway, useValue: { sendToUser: jest.fn() } },
        {
          provide: JobsService,
          useValue: {
            queueNotification: jest.fn(),
            queueCircleMilestone: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get(CirclesService);
  });

  it('acceptRequest should update membership and create reciprocal membership', async () => {
    prisma.circleMembership.findFirst.mockResolvedValue({
      id: 'm1',
      accepted: false,
    });
    prisma.circleMembership.update.mockResolvedValue({
      id: 'm1',
      accepted: true,
    });
    prisma.circleMembership.create.mockResolvedValue({
      id: 'm2',
      accepted: true,
    });

    await service.acceptRequest('member-id', 'sender-id');
    expect(prisma.circleMembership.update).toHaveBeenCalled();
    expect(prisma.circleMembership.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { userId: 'member-id', memberId: 'sender-id', accepted: true },
      }),
    );
  });

  it('acceptRequest should handle P2002 and update existing reciprocal to accepted', async () => {
    prisma.circleMembership.findFirst.mockResolvedValue({
      id: 'm1',
      accepted: false,
    });
    prisma.circleMembership.update.mockResolvedValue({
      id: 'm1',
      accepted: true,
    });
    const p2002 = new Error('Unique constraint');
    (p2002 as Error & { code?: string }).code = 'P2002';
    prisma.circleMembership.create.mockRejectedValue(p2002);
    prisma.circleMembership.findFirst
      .mockResolvedValueOnce({ id: 'm1', accepted: false })
      .mockResolvedValueOnce({ id: 'm3', accepted: false });
    prisma.circleMembership.update.mockResolvedValue({
      id: 'm3',
      accepted: true,
    });

    await service.acceptRequest('member-id', 'sender-id');
    expect(prisma.circleMembership.update).toHaveBeenCalled();
  });
});
