import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../src/prisma/prisma.service';

// Mock pg.Pool to prevent trying to connect to a real database during unit tests
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

describe('Prisma Soft Delete Extension', () => {
  let service: PrismaService;

  beforeEach(async () => {
    // Stub $connect and $disconnect to avoid network/database dependency
    jest.spyOn(PrismaService.prototype, '$connect').mockResolvedValue(undefined);
    jest.spyOn(PrismaService.prototype, '$disconnect').mockResolvedValue(undefined);

    const module: TestingModule = await Test.createTestingModule({
      providers: [PrismaService],
    }).compile();

    service = module.get<PrismaService>(PrismaService);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should be defined and return the proxy', () => {
    expect(service).toBeDefined();
    expect((service as any).extendedClient).toBeDefined();
  });

  it('should verify soft delete logic applies to User, Memory, Message, and CircleMembership models via middleware method', async () => {
    const softDeleteModels = ['User', 'Memory', 'Message', 'CircleMembership'];
    
    for (const modelName of softDeleteModels) {
      const modelKey = modelName.charAt(0).toLowerCase() + modelName.slice(1);
      
      // Mock client models to capture redirected calls
      const mockClientModel = {
        findFirst: jest.fn().mockResolvedValue({ id: 'test-id' }),
        findFirstOrThrow: jest.fn().mockResolvedValue({ id: 'test-id' }),
        update: jest.fn().mockResolvedValue({ id: 'test-id' }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      };

      const dummyClient = {
        [modelKey]: mockClientModel,
      };

      const mockQuery = jest.fn().mockResolvedValue({ id: 'test-id' });

      // 1. Test findUnique converts to findFirst
      await service.softDeleteQueryMiddleware(
        modelName,
        'findUnique',
        { where: { id: 'test-id' } },
        mockQuery,
        dummyClient
      );
      expect(mockClientModel.findFirst).toHaveBeenCalledWith({
        where: { id: 'test-id' }
      });
      expect(mockQuery).not.toHaveBeenCalled();

      // 2. Test findUniqueOrThrow converts to findFirstOrThrow
      await service.softDeleteQueryMiddleware(
        modelName,
        'findUniqueOrThrow',
        { where: { id: 'test-id' } },
        mockQuery,
        dummyClient
      );
      expect(mockClientModel.findFirstOrThrow).toHaveBeenCalledWith({
        where: { id: 'test-id' }
      });
      expect(mockQuery).not.toHaveBeenCalled();

      // 3. Test findFirst injects deletedAt: null
      await service.softDeleteQueryMiddleware(
        modelName,
        'findFirst',
        { where: { id: 'test-id' } },
        mockQuery,
        dummyClient
      );
      expect(mockQuery).toHaveBeenCalledWith({
        where: { id: 'test-id', deletedAt: null }
      });

      mockQuery.mockClear();

      // 4. Test findMany preserves explicit deletedAt query if supplied
      const explicitDate = new Date('2026-01-01');
      await service.softDeleteQueryMiddleware(
        modelName,
        'findMany',
        { where: { deletedAt: explicitDate } },
        mockQuery,
        dummyClient
      );
      expect(mockQuery).toHaveBeenCalledWith({
        where: { deletedAt: explicitDate }
      });

      mockQuery.mockClear();

      // 5. Test delete converts to update with deletedAt
      await service.softDeleteQueryMiddleware(
        modelName,
        'delete',
        { where: { id: 'test-id' } },
        mockQuery,
        dummyClient
      );
      expect(mockClientModel.update).toHaveBeenCalledWith({
        where: { id: 'test-id' },
        data: { deletedAt: expect.any(Date) }
      });
      expect(mockQuery).not.toHaveBeenCalled();

      // 6. Test deleteMany converts to updateMany with deletedAt
      await service.softDeleteQueryMiddleware(
        modelName,
        'deleteMany',
        { where: { id: 'test-id' } },
        mockQuery,
        dummyClient
      );
      expect(mockClientModel.updateMany).toHaveBeenCalledWith({
        where: { id: 'test-id' },
        data: { deletedAt: expect.any(Date) }
      });
      expect(mockQuery).not.toHaveBeenCalled();
    }
  });

  it('should NOT intercept non-soft-delete models like Reaction', async () => {
    const mockQuery = jest.fn().mockResolvedValue({ id: 'test-id' });
    const dummyClient = {};

    await service.softDeleteQueryMiddleware(
      'Reaction',
      'findMany',
      { where: { emoji: '👍' } },
      mockQuery,
      dummyClient
    );
    
    expect(mockQuery).toHaveBeenCalledWith({
      where: { emoji: '👍' },
    });
    expect(mockQuery.mock.calls[0][0].where.deletedAt).toBeUndefined();
  });
});
