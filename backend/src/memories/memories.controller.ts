import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
  ParseFilePipe,
  MaxFileSizeValidator,
  FileTypeValidator,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { MemoriesService } from './memories.service';
import { StorageService } from '../storage/storage.service';
import { CreateMemoryDto } from './dto/create-memory.dto';
import { UploadMemoryDto } from './dto/upload-memory.dto';
import { PrismaService } from '../prisma/prisma.service';

// ─── Colour palette seeded from user ID (deterministic, no extra DB field) ───

const PALETTE = [
  '#FF6B57', '#FFBA57', '#57BA96', '#5784FF', '#C157FF',
  '#FF578B', '#57D3FF', '#FF9F57', '#82C341', '#FF57B7',
];

function seedColor(userId: string): string {
  let hash = 0;
  for (let i = 0; i < userId.length; i++) {
    hash = (hash * 31 + userId.charCodeAt(i)) >>> 0;
  }
  return PALETTE[hash % PALETTE.length];
}

// ─── Relative time helper ────────────────────────────────────────────────────

function relativeTime(date: Date): string {
  const diffMs = Date.now() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  if (diffMins < 1)   return 'Just now';
  if (diffMins < 60)  return `${diffMins}m ago`;
  const diffHrs = Math.floor(diffMins / 60);
  if (diffHrs < 24)   return `${diffHrs}h ago`;
  const diffDays = Math.floor(diffHrs / 24);
  return `${diffDays}d ago`;
}

// ─── Map a DB memory record → Flutter MemoryItem shape ──────────────────────

function toMemoryItem(m: any): Record<string, unknown> {
  const now = Date.now();
  const createdAt = new Date(m.createdAt);
  const ageMs = now - createdAt.getTime();
  const ageHours = ageMs / 3_600_000;

  const firstName: string = m.creator?.firstName ?? '';
  const initial   = firstName.length > 0 ? firstName[0].toUpperCase() : '?';

  return {
    id:              m.id,
    person:          firstName,
    initial:         initial,
    time:            relativeTime(createdAt),
    caption:         m.caption,
    avatar:          seedColor(m.creator?.id ?? m.creatorId),
    gradient_colors: m.gradientColors ?? [],
    video_url:       m.videoUrl,
    age_hours:       Math.round(ageHours * 100) / 100,
    creator: {
      id:         m.creator?.id,
      username:   m.creator?.username,
      avatar_url: m.creator?.avatarUrl ?? null,
    },
  };
}

@UseGuards(JwtAuthGuard)
@Controller('memories')
export class MemoriesController {
  constructor(
    private readonly memoriesService: MemoriesService,
    private readonly storageService: StorageService,
    private readonly prisma: PrismaService,
  ) {}

  // ─── GET /memories/feed?page=1&limit=20 ──────────────────────────────────
  // Returns: { memories: [...], meta: { page, limit, total, totalPages } }

  @Get('feed')
  async getFeed(
    @Req() req: any,
    @Query('page')  page  = '1',
    @Query('limit') limit = '20',
  ) {
    const result = await this.memoriesService.getFeed(
      req.user.id,
      parseInt(page, 10),
      parseInt(limit, 10),
    );
    return {
      memories: result.data.map(toMemoryItem),
      meta: result.meta,
    };
  }

  // ─── GET /memories/:id ───────────────────────────────────────────────────

  @Get(':id')
  async getMemory(@Req() req: any, @Param('id') id: string) {
    const m = await this.memoriesService.getById(id);
    if (!m) return null;

    // Users should only see memories from users in their circle (or themselves)
    if (m.creatorId !== req.user.id) {
      const isMember = await this.prisma.circleMembership.findUnique({
        where: {
          unique_user_member: {
            userId: req.user.id,
            memberId: m.creatorId,
          },
        },
      });
      if (!isMember || !isMember.accepted) {
        return null;
      }
    }

    return toMemoryItem(m);
  }

  // ─── POST /memories/upload (multipart video + metadata) ──────────────────
  // Flutter form fields: { video: <file>, caption: str, colors: str|list }

  @Post('upload')
  @UseInterceptors(FileInterceptor('video'))
  async uploadMemory(
    @Req() req: any,
    @Body() dto: UploadMemoryDto,
    @UploadedFile(
      new ParseFilePipe({
        validators: [
          new MaxFileSizeValidator({ maxSize: 50 * 1024 * 1024 }),
          new FileTypeValidator({ fileType: /(video\/mp4|video\/quicktime|video\/webm)/ }),
        ],
      }),
    )
    file: Express.Multer.File,
  ) {
    const videoUrl = await this.storageService.uploadFile(file, 'memories');

    let gradientColors: string[] = [];
    if (dto.colors) {
      if (Array.isArray(dto.colors)) {
        gradientColors = dto.colors;
      } else if (typeof dto.colors === 'string') {
        if (dto.colors.startsWith('[')) {
          try { gradientColors = JSON.parse(dto.colors); } catch { gradientColors = [dto.colors]; }
        } else {
          gradientColors = dto.colors.split(',').map((c: string) => c.trim());
        }
      }
    }

    const m = await this.memoriesService.create(req.user.id, {
      caption: dto.caption || '',
      videoUrl,
      gradientColors,
    });

    return toMemoryItem(m);
  }

  // ─── POST /memories (metadata-only, video URL provided externally) ────────

  @Post()
  async createMemory(@Req() req: any, @Body() dto: CreateMemoryDto) {
    const m = await this.memoriesService.create(req.user.id, dto);
    return toMemoryItem(m);
  }
}
