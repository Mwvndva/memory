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
  MaxFileSizeValidator,
  FileTypeValidator,
  Delete,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { UsersService } from './users.service';
import { StorageService } from '../storage/storage.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { SyncContactsDto } from './dto/sync-contacts.dto';

@Controller('users')
export class UsersController {
  constructor(
    private readonly usersService: UsersService,
    private readonly storageService: StorageService,
  ) {}

  /**
   * GET /users/check-username?username=john_doe
   * Public — checks whether a username is still available.
   */
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
  getMe(@Req() req: any) {
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
    @Req() req: any,
    @UploadedFile(
      new ParseFilePipe({
        validators: [
          new MaxFileSizeValidator({ maxSize: 5 * 1024 * 1024 }), // 5 MB
          new FileTypeValidator({ fileType: /(image\/jpeg|image\/png|image\/webp)/ }),
        ],
      }),
    )
    file: Express.Multer.File,
  ) {
    const avatarUrl = await this.storageService.uploadFile(file, 'avatars');
    return this.usersService.updateProfile(req.user.id, { avatarUrl });
  }

  /**
   * GET /users/:id
   * Authenticated — retrieve any user's public profile.
   */
  @UseGuards(JwtAuthGuard)
  @Get(':id')
  getUser(@Param('id') id: string) {
    return this.usersService.getProfile(id);
  }

  /**
   * PATCH /users/profile
   * Authenticated — partial update of the current user's profile.
   */
  @UseGuards(JwtAuthGuard)
  @Patch('profile')
  updateProfile(@Req() req: any, @Body() dto: UpdateProfileDto) {
    return this.usersService.updateProfile(req.user.id, dto);
  }

  /**
   * POST /users/sync-contacts
   * Authenticated — syncs contact list to find matching users on Memory.
   */
  @UseGuards(JwtAuthGuard)
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
  deleteMe(@Req() req: any) {
    return this.usersService.deleteAccount(req.user.id);
  }

  /**
   * GET /users/me/export
   * Authenticated — GDPR Right to Data Portability personal data export.
   */
  @UseGuards(JwtAuthGuard)
  @Get('me/export')
  exportMe(@Req() req: any) {
    return this.usersService.exportUserData(req.user.id);
  }
}
