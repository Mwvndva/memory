import { Test, TestingModule } from '@nestjs/testing';
import { CirclesService } from '../src/circles/circles.service';

describe('CirclesService', () => {
  let service: CirclesService;

  beforeEach(async () => {
    const prismaMock: any = {
      circleMembership: {
        findFirst: jest.fn(),
        update: jest.fn(),
        create: jest.fn(),
      },
      user: { findUnique: jest.fn() },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CirclesService,
        { provide: 'PrismaService', useValue: prismaMock },
        { provide: 'AppGateway', useValue: { sendToUser: jest.fn() } },
      ],
    }).compile();

    service = module.get(CirclesService);
    (service as any).prisma = prismaMock; // inject mock
  });

  it('acceptRequest should update membership and create reciprocal membership', async () => {
    const prisma: any = (service as any).prisma;
    prisma.circleMembership.findFirst.mockResolvedValue({ id: 'm1', accepted: false });
    prisma.circleMembership.update.mockResolvedValue({ id: 'm1', accepted: true });
    prisma.circleMembership.create.mockResolvedValue({ id: 'm2', accepted: true });

    const res = await service.acceptRequest('member-id', 'sender-id');
    expect(prisma.circleMembership.update).toHaveBeenCalled();
    expect(prisma.circleMembership.create).toHaveBeenCalledWith(expect.objectContaining({ data: { userId: 'member-id', memberId: 'sender-id', accepted: true } }));
  });

  it('acceptRequest should handle P2002 and update existing reciprocal to accepted', async () => {
    const prisma: any = (service as any).prisma;
    prisma.circleMembership.findFirst.mockResolvedValue({ id: 'm1', accepted: false });
    prisma.circleMembership.update.mockResolvedValue({ id: 'm1', accepted: true });
    const p2002 = new Error('Unique constraint');
    (p2002 as any).code = 'P2002';
    prisma.circleMembership.create.mockRejectedValue(p2002);
    prisma.circleMembership.findFirst.mockResolvedValueOnce({ id: 'm1', accepted: false }).mockResolvedValueOnce({ id: 'm3', accepted: false });
    prisma.circleMembership.update.mockResolvedValue({ id: 'm3', accepted: true });

    const res = await service.acceptRequest('member-id', 'sender-id');
    expect(prisma.circleMembership.update).toHaveBeenCalled();
  });
});
