import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

@Injectable()
export class StorageService implements OnModuleInit {
  private readonly logger = new Logger(StorageService.name);
  private s3Client: S3Client | null = null;
  private bucketName: string;
  private publicUrl: string;
  private isR2Configured = false;
  private localUploadsDir: string;

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    const endpoint = this.configService.get<string>('R2_ENDPOINT');
    const accessKeyId = this.configService.get<string>('R2_ACCESS_KEY_ID');
    const secretAccessKey = this.configService.get<string>('R2_SECRET_ACCESS_KEY');
    this.bucketName = this.configService.get<string>('R2_BUCKET_NAME', '');
    this.publicUrl = this.configService.get<string>('R2_PUBLIC_URL', '');

    // Resolve local directory path (project_root/uploads)
    this.localUploadsDir = path.join(process.cwd(), 'uploads');

    if (endpoint && accessKeyId && secretAccessKey && this.bucketName) {
      try {
        this.s3Client = new S3Client({
          endpoint,
          credentials: {
            accessKeyId,
            secretAccessKey,
          },
          region: 'auto',
        });
        this.isR2Configured = true;
        this.logger.log('✅ Cloudflare R2 client initialized successfully.');
      } catch (err) {
        this.logger.error('Failed to initialize Cloudflare R2 client, falling back to local storage.', err);
      }
    } else {
      this.logger.warn('⚠️ Cloudflare R2 credentials not fully set in .env. Falling back to local disk storage.');
    }

    // Ensure local directory exists
    if (!fs.existsSync(this.localUploadsDir)) {
      fs.mkdirSync(this.localUploadsDir, { recursive: true });
    }
  }

  async uploadFile(file: Express.Multer.File, folder: string): Promise<string> {
    const fileExt = path.extname(file.originalname);
    const uniqueFilename = `${crypto.randomUUID()}${fileExt}`;
    const fileKey = `${folder}/${uniqueFilename}`;

    if (this.isR2Configured && this.s3Client) {
      try {
        await this.s3Client.send(
          new PutObjectCommand({
            Bucket: this.bucketName,
            Key: fileKey,
            Body: file.buffer,
            ContentType: file.mimetype,
          }),
        );
        
        // Clean trailing slash if present on the public base URL
        const baseUrl = this.publicUrl.endsWith('/') ? this.publicUrl.slice(0, -1) : this.publicUrl;
        return `${baseUrl}/${fileKey}`;
      } catch (err) {
        this.logger.error(`R2 upload failed for key ${fileKey}, falling back to local saving`, err);
      }
    }

    // Local Storage Fallback
    const destinationDir = path.join(this.localUploadsDir, folder);
    if (!fs.existsSync(destinationDir)) {
      fs.mkdirSync(destinationDir, { recursive: true });
    }

    const localPath = path.join(destinationDir, uniqueFilename);
    await fs.promises.writeFile(localPath, file.buffer);

    // Get server port from configuration
    const port = this.configService.get<number>('PORT', 3000);
    return `http://localhost:${port}/uploads/${folder}/${uniqueFilename}`;
  }
}
