import {
  IsEmail,
  IsString,
  MinLength,
  MaxLength,
  Matches,
  IsBoolean,
  IsOptional,
} from 'class-validator';
import { normalizeEmail, normalizePhone, normalizeUsername, isProtectedUsername } from '../auth-normalization';

export class RegisterDto {
  @IsString()
  @MaxLength(50)
  @IsOptional()
  firstName?: string;

  @IsString()
  @MaxLength(50)
  @IsOptional()
  lastName?: string;

  @IsString()
  @MaxLength(50)
  @IsOptional()
  first_name?: string;

  @IsString()
  @MaxLength(50)
  @IsOptional()
  last_name?: string;

  @IsString()
  @MinLength(3)
  @MaxLength(30)
  @Matches(/^[a-zA-Z0-9_]+$/, {
    message: 'Username may only contain letters, numbers, and underscores',
  })
  username: string;

  @IsEmail()
  email: string;

  @IsString()
  @MaxLength(20)
  phone: string;

  @IsString()
  @MinLength(8)
  @MaxLength(128) // bound input; also avoids pathological hashing cost
  password: string;

  @IsBoolean()
  @IsOptional()
  acceptedTerms?: boolean;

  @IsBoolean()
  @IsOptional()
  accepted_terms?: boolean;

  constructor(partial?: Partial<RegisterDto>) {
    Object.assign(this, partial);
    if (typeof this.username === 'string') {
      this.username = normalizeUsername(this.username);
    }
    if (typeof this.email === 'string') {
      this.email = normalizeEmail(this.email);
    }
    if (typeof this.phone === 'string') {
      this.phone = normalizePhone(this.phone);
    }
  }

  isProtectedUsername(): boolean {
    return isProtectedUsername(this.username);
  }
}
