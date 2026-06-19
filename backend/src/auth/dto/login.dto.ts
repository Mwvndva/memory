import { IsString } from 'class-validator';

export class LoginDto {
  /** Accepts either an email address or a username. */
  @IsString()
  identifier: string;

  @IsString()
  password: string;
}
