import { IsString, IsOptional } from 'class-validator';

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
}
