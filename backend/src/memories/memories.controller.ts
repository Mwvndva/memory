import {
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
  ParseFilePipe,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { MemoriesService, MemoryWithCreator } from './memories.service';
import { StorageService } from '../storage/storage.service';
import { RedisService } from '../redis/redis.service';
import { videoFileValidators } from '../storage/file-signature.validator';
import { CreateMemoryDto } from './dto/create-memory.dto';
import { UpdateMemoryDto } from './dto/update-memory.dto';
import { UploadMemoryDto } from './dto/upload-memory.dto';
import { PrismaService } from '../prisma/prisma.service';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

// ─── Colour palette seeded from user ID (deterministic, no extra DB field) ───

const PALETTE = [
  '#FF6B57',
  '#FFBA57',
  '#57BA96',
  '#5784FF',
  '#C157FF',
  '#FF578B',
  '#57D3FF',
  '#FF9F57',
  '#82C341',
  '#FF57B7',
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
  if (diffMins < 1) return 'Just now';
  if (diffMins < 60) return `${diffMins}m ago`;
  const diffHrs = Math.floor(diffMins / 60);
  if (diffHrs < 24) return `${diffHrs}h ago`;
  const diffDays = Math.floor(diffHrs / 24);
  return `${diffDays}d ago`;
}

// ─── Map a DB memory record → Flutter MemoryItem shape ──────────────────────

/**
 * [reactions] is the emoji → count map for this memory. The client reads it as
 * `reactions: [{ emoji, count }]`; omitting it leaves every reaction count at
 * zero in the UI, so it is a required argument rather than an optional one.
 */
function toMemoryItem(
  m: MemoryWithCreator,
  reactions: Record<string, number>,
): Record<string, unknown> {
  const now = Date.now();
  const createdAt = new Date(m.createdAt);
  const ageMs = now - createdAt.getTime();
  const ageHours = ageMs / 3_600_000;

  const firstName: string = m.creator?.firstName ?? '';
  const initial = firstName.length > 0 ? firstName[0].toUpperCase() : '?';

  return {
    id: m.id,
    person: firstName,
    initial: initial,
    time: relativeTime(createdAt),
    caption: m.caption,
    avatar: seedColor(m.creator?.id ?? m.creatorId),
    gradient_colors: m.gradientColors ?? [],
    video_url: m.videoUrl,
    age_hours: Math.round(ageHours * 100) / 100,
    reactions: Object.entries(reactions).map(([emoji, count]) => ({
      emoji,
      count,
    })),
    creator: {
      id: m.creator?.id,
      username: m.creator?.username,
      avatar_url: m.creator?.avatarUrl ?? null,
    },
  };
}

/** Normalise the `colors` form field into a list of colour strings. */
function parseGradientColors(colors: string | string[] | undefined): string[] {
  if (!colors) return [];
  if (Array.isArray(colors)) return colors;
  if (colors.startsWith('[')) {
    try {
      const parsed: unknown = JSON.parse(colors);
      if (Array.isArray(parsed)) {
        return parsed.filter((c): c is string => typeof c === 'string');
      }
    } catch {
      // Not JSON after all — fall through and treat it as a single value.
    }
    return [colors];
  }
  return colors.split(',').map((c) => c.trim());
}

@UseGuards(JwtAuthGuard)
@Controller('memories')
export class MemoriesController {
  constructor(
    private readonly memoriesService: MemoriesService,
    private readonly storageService: StorageService,
    private readonly redisService: RedisService,
    private readonly prisma: PrismaService,
  ) {}

  // ─── GET /memories/feed?cursor=...&limit=20 ──────────────────────────────
  // Returns: { memories: [...], meta: { nextCursor, limit } }

  @Get('feed')
  async getFeed(
    @Req() req: AuthenticatedRequest,
    @Query('cursor') cursor?: string,
    @Query('limit') limit = '20',
  ) {
    const result = await this.memoriesService.getFeed(
      req.user.id,
      cursor,
      parseInt(limit, 10),
    );

    // One bulk lookup for the whole page rather than one per memory.
    const ids = result.data.map((m) => m.id);
    const reactions = await this.redisService.getReactionsMany(ids);

    return {
      memories: result.data.map((m) =>
        toMemoryItem(m, reactions.get(m.id) ?? {}),
      ),
      meta: result.meta,
    };
  }

  // ─── GET /memories/:id ───────────────────────────────────────────────────

  @Get(':id')
  async getMemory(@Req() req: AuthenticatedRequest, @Param('id') id: string) {
    const m = await this.memoriesService.getById(id);
    // A missing memory and one outside the caller's circle are reported
    // identically, so this endpoint cannot be used to probe for existence.
    if (!m) throw new NotFoundException('Memory not found');

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
        throw new NotFoundException('Memory not found');
      }
    }

    const reactions = await this.redisService.getReactions(id);
    return toMemoryItem(m, reactions);
  }

  // ─── PATCH /memories/:id ─────────────────────────────────────────────────
  // Edit a memory's caption. Owner only.

  @Patch(':id')
  async updateMemory(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
    @Body() dto: UpdateMemoryDto,
  ) {
    const m = await this.memoriesService.updateCaption(
      id,
      req.user.id,
      dto.caption,
    );
    const reactions = await this.redisService.getReactions(id);
    return toMemoryItem(m, reactions);
  }

  // ─── DELETE /memories/:id ────────────────────────────────────────────────
  // Soft-delete a memory. Owner only.

  @Delete(':id')
  async deleteMemory(
    @Req() req: AuthenticatedRequest,
    @Param('id') id: string,
  ) {
    return this.memoriesService.remove(id, req.user.id);
  }

  // ─── POST /memories/upload (multipart video + metadata) ──────────────────
  // Flutter form fields: { video: <file>, caption: str, colors: str|list }

  @Post('upload')
  @UseInterceptors(FileInterceptor('video'))
  async uploadMemory(
    @Req() req: AuthenticatedRequest,
    @Body() dto: UploadMemoryDto,
    @UploadedFile(
      new ParseFilePipe({
        validators: videoFileValidators(50 * 1024 * 1024), // 50 MB, magic-byte checked
      }),
    )
    file: Express.Multer.File,
  ) {
    const videoUrl = await this.storageService.uploadFile(file, 'memories');

    const gradientColors = parseGradientColors(dto.colors);

    const m = await this.memoriesService.create(req.user.id, {
      caption: dto.caption || '',
      videoUrl,
      gradientColors,
    });

    // Freshly created: no reactions yet.
    return toMemoryItem(m, {});
  }

  // ─── POST /memories (metadata-only, video URL provided externally) ────────

  @Post()
  async createMemory(
    @Req() req: AuthenticatedRequest,
    @Body() dto: CreateMemoryDto,
  ) {
    const m = await this.memoriesService.create(req.user.id, dto);
    // Freshly created: no reactions yet.
    return toMemoryItem(m, {});
  }
}
