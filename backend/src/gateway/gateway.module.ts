import { Module } from '@nestjs/common';
import { AppGateway } from './app.gateway';
import { MessagesModule } from '../messages/messages.module';

@Module({
  imports: [
    MessagesModule,  // provides MessagesService for DB persistence
    // AuthModule no longer needed — gateway authenticates via one-time Redis tickets,
    // not by verifying JWTs directly.  JwtService dependency removed from AppGateway.
  ],
  providers: [AppGateway],
  exports: [AppGateway],
})
export class GatewayModule {}
