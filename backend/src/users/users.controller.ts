import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
  ParseFilePipe,
  Delete,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RateLimitGuard } from '../auth/guards/rate-limit.guard';
import { RateLimit } from '../auth/decorators/rate-limit.decorator';
import { UsersService } from './users.service';
import { StorageService } from '../storage/storage.service';
import { imageFileValidators } from '../storage/file-signature.validator';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { SyncContactsDto } from './dto/sync-contacts.dto';
import type { AuthenticatedRequest } from '../auth/authenticated-request';

@Controller('users')
export class UsersController {
  constructor(
    private readonly usersService: UsersService,
    private readonly storageService: StorageService,
  ) {}

  /**
   * GET /users/check-username?username=john_doe
   * Public — checks whether a username is still available.
   * Rate-limited to curb username enumeration.
   */
  @UseGuards(RateLimitGuard)
  @RateLimit({ limit: 20, windowSeconds: 60 })
  @Get('check-username')
  checkUsername(@Query('username') username: string) {
    return this.usersService.checkUsername(username);
  }

  /**
   * GET /users/me
   * Authenticated — returns the current user's full profile.
   */
  @UseGuards(JwtAuthGuard)
  @Get('me')
  getMe(@Req() req: AuthenticatedRequest) {
    return this.usersService.getProfile(req.user.id);
  }

  /**
   * POST /users/me/avatar
   * Authenticated — uploads an avatar image (multipart form key 'file').
   * Enforces max 5MB size and image MIME types (JPEG, PNG, WebP).
   */
  @UseGuards(JwtAuthGuard)
  @Post('me/avatar')
  @UseInterceptors(FileInterceptor('file'))
  async uploadAvatar(
    @Req() req: AuthenticatedRequest,
    @UploadedFile(
      new ParseFilePipe({
        validators: imageFileValidators(5 * 1024 * 1024), // 5 MB, magic-byte checked
      }),
    )
    file: Express.Multer.File,
  ) {
    const avatarUrl = await this.storageService.uploadFile(file, 'avatars');
    return this.usersService.updateProfile(req.user.id, { avatarUrl });
  }

  /**
   * GET /users/:id
   * Authenticated — retrieve another user's PUBLIC profile.
   * Excludes PII (email, phone) — those are only returned for /users/me.
   */
  @UseGuards(JwtAuthGuard)
  @Get(':id')
  getUser(@Req() req: AuthenticatedRequest, @Param('id') id: string) {
    // The caller can always see their own full profile.
    if (id === req.user.id) return this.usersService.getProfile(id);
    return this.usersService.getPublicProfile(id);
  }

  /**
   * PATCH /users/profile
   * Authenticated — partial update of the current user's profile.
   */
  @UseGuards(JwtAuthGuard)
  @Patch('profile')
  updateProfile(
    @Req() req: AuthenticatedRequest,
    @Body() dto: UpdateProfileDto,
  ) {
    return this.usersService.updateProfile(req.user.id, dto);
  }

  /**
   * POST /users/me/fcm
   * Authenticated — updates/registers the FCM registration token for push notifications.
   */
  @UseGuards(JwtAuthGuard)
  @Post('me/fcm')
  updateFcmToken(
    @Req() req: AuthenticatedRequest,
    @Body() body: { fcmToken?: string; fcm_token?: string },
  ) {
    const fcmToken = body.fcmToken ?? body.fcm_token;
    return this.usersService.updateProfile(req.user.id, { fcmToken });
  }

  /**
   * POST /users/sync-contacts
   * Authenticated — syncs contact list to find matching users on Memory.
   */
  @UseGuards(JwtAuthGuard, RateLimitGuard)
  @RateLimit({ limit: 10, windowSeconds: 3600 })
  @Post('sync-contacts')
  syncContacts(@Body() dto: SyncContactsDto) {
    return this.usersService.findByPhones(dto.phones);
  }

  /**
   * DELETE /users/me
   * Authenticated — GDPR Right to Erasure user account deletion.
   */
  @UseGuards(JwtAuthGuard)
  @Delete('me')
  deleteMe(@Req() req: AuthenticatedRequest) {
    return this.usersService.deleteAccount(req.user.id);
  }

  /**
   * GET /users/me/export
   * Authenticated — GDPR Right to Data Portability personal data export.
   */
  @UseGuards(JwtAuthGuard)
  @Get('me/export')
  exportMe(@Req() req: AuthenticatedRequest) {
    return this.usersService.exportUserData(req.user.id);
  }
}
