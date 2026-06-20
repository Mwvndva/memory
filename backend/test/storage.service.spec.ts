import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { StorageService } from '../src/storage/storage.service';
import * as fs from 'fs';
import * as path from 'path';

describe('StorageService (Local Fallback)', () => {
  let service: StorageService;
  const dummyFile: Express.Multer.File = {
    fieldname: 'file',
    originalname: 'test.mp4',
    encoding: '7bit',
    mimetype: 'video/mp4',
    buffer: Buffer.from('dummy video data'),
    size: 16,
    destination: '',
    filename: '',
    path: '',
    stream: null as any,
  };

  beforeEach(async () => {
    const configServiceMock = {
      get: jest.fn().mockImplementation((key: string, defaultValue?: any) => {
        if (key === 'PORT') return 3000;
        return defaultValue;
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        StorageService,
        { provide: ConfigService, useValue: configServiceMock },
      ],
    }).compile();

    service = module.get<StorageService>(StorageService);
    // Explicitly call onModuleInit to initialize local uploads directory paths
    service.onModuleInit();
  });

  afterAll(() => {
    // Cleanup files written to local destination during tests if folder exists
    const localDir = path.join(process.cwd(), 'uploads', 'test-memories');
    if (fs.existsSync(localDir)) {
      fs.rmSync(localDir, { recursive: true, force: true });
    }
  });

  it('should fallback to local disk and save the file buffer', async () => {
    const url = await service.uploadFile(dummyFile, 'test-memories');
    
    // Assert url is local fallback url
    expect(url).toContain('http://localhost:3000/uploads/test-memories/');
    
    // Assert file actually exists on disk
    const urlParts = url.split('/');
    const filename = urlParts[urlParts.length - 1];
    const filePath = path.join(process.cwd(), 'uploads', 'test-memories', filename);
    
    expect(fs.existsSync(filePath)).toBe(true);
    const content = fs.readFileSync(filePath, 'utf-8');
    expect(content).toBe('dummy video data');
  });
});
