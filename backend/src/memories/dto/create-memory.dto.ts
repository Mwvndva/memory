import {
  IsArray,
  IsString,
  IsUrl,
  MaxLength,
  ArrayMaxSize,
} from 'class-validator';

export class CreateMemoryDto {
  @IsString()
  @MaxLength(500)
  caption: string;

  @IsUrl()
  videoUrl: string;

  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(5)
  gradientColors: string[];
}
