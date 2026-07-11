import { Module } from '@nestjs/common';
import { CirclesService } from './circles.service';
import { CirclesController } from './circles.controller';
import { GatewayModule } from '../gateway/gateway.module';

@Module({
  imports: [GatewayModule],
  providers: [CirclesService],
  controllers: [CirclesController],
  exports: [CirclesService],
})
export class CirclesModule {}
