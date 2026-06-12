import { Module } from '@nestjs/common';
import { AppGateway } from './app.gateway';
import { MessagesModule } from '../messages/messages.module';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [
    AuthModule,      // provides JwtModule → JwtService for token verification
    MessagesModule,  // provides MessagesService for DB persistence
  ],
  providers: [AppGateway],
})
export class GatewayModule {}
