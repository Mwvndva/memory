import { Test, TestingModule } from '@nestjs/testing';
import { MessagesController } from '../src/messages/messages.controller';
import { MessagesService } from '../src/messages/messages.service';

describe('MessagesController', () => {
  let controller: MessagesController;
  let messagesService: Partial<MessagesService>;

  beforeEach(async () => {
    messagesService = {
      getConversation: jest.fn().mockResolvedValue({ data: [{ id: 'm1', text: 'hi' }], meta: {} }),
      markRead: jest.fn().mockResolvedValue(undefined),
    };

    const prismaMock = {
      circleMembership: {
        findFirst: jest.fn().mockResolvedValue({ id: 'rel', accepted: true }),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [MessagesController],
      providers: [
        { provide: MessagesService, useValue: messagesService },
        { provide: 'PrismaService', useValue: prismaMock },
      ],
    }).compile();

    controller = module.get(MessagesController);
  });

  it('should return conversation when either-direction membership exists', async () => {
    const req: any = { user: { id: 'user-a' } };
    const result = await controller.getHistory(req, 'user-b', '1', '50');
    expect((messagesService.getConversation as jest.Mock).mock.calls.length).toBe(1);
    expect(result).toHaveProperty('data');
  });
});
