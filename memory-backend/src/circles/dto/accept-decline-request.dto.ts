import { IsUUID } from 'class-validator';

export class AcceptDeclineRequestDto {
  @IsUUID()
  senderId: string;
}
