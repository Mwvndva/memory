import { IsArray, IsString, ArrayMaxSize, MaxLength } from 'class-validator';

export class SyncContactsDto {
  @IsArray()
  @ArrayMaxSize(2000) // cap payload → limits mass enumeration / DoS
  @IsString({ each: true })
  @MaxLength(40, { each: true })
  phones: string[];
}
