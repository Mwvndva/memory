import { IsString, IsOptional } from 'class-validator';
import { normalizeUsername } from '../auth-normalization';

export class LoginDto {
  /** Accepts either an email address or a username. */
  @IsString()
  @IsOptional()
  identity?: string;

  @IsString()
  @IsOptional()
  identifier?: string;

  @IsString()
  password: string;

  constructor(partial?: Partial<LoginDto>) {
    Object.assign(this, partial);
    if (typeof this.identity === 'string') {
      this.identity = this.identity.trim();
    }
    if (typeof this.identifier === 'string') {
      this.identifier = this.identifier.trim();
    }
  }

  get normalizedIdentity(): string {
    const raw = this.identity ?? this.identifier ?? '';
    const trimmed = raw.trim();
    return trimmed.includes('@')
      ? trimmed.toLowerCase()
      : normalizeUsername(trimmed);
  }
}
