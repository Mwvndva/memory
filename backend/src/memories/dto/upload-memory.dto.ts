import { IsString, IsOptional } from 'class-validator';

export class UploadMemoryDto {
  @IsString()
  @IsOptional()
  caption?: string;

  @IsOptional()
  colors?: any;
}
