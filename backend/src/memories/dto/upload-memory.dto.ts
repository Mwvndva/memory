import { IsString, IsOptional } from 'class-validator';

export class UploadMemoryDto {
  @IsString()
  @IsOptional()
  caption?: string;

  /**
   * Multipart form fields arrive as strings; the client may send either a JSON
   * array (`["#fff"]`), a comma-separated list, or repeated fields (an array).
   */
  @IsOptional()
  colors?: string | string[];
}
