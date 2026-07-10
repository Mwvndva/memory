import { IsString, MaxLength } from 'class-validator';

export class UpdateMemoryDto {
  @IsString()
  @MaxLength(500)
  caption: string;
}
