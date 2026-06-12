import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { ValidationPipe } from '@nestjs/common';
import { WsAdapter } from '@nestjs/platform-ws';
import helmet from 'helmet';
import * as express from 'express';
import * as path from 'path';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const configService = app.get(ConfigService);

  // ── 1. Security headers (Helmet) ─────────────────────────────────────────
  app.use(
    helmet({
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    }),
  );

  // ── 2. Trust proxy headers (needed for accurate IP in RateLimitGuard) ────
  app.getHttpAdapter().getInstance().set('trust proxy', 1);

  // ── 3. CORS — env-driven origin whitelist ────────────────────────────────
  const rawOrigins = configService.get<string>(
    'ALLOWED_ORIGINS',
    'http://localhost:3000,http://localhost:8080',
  );
  const allowedOrigins = rawOrigins
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);

  app.enableCors({
    origin: (requestOrigin, callback) => {
      if (!requestOrigin) return callback(null, true);
      if (allowedOrigins.includes(requestOrigin)) return callback(null, true);
      callback(new Error(`CORS: origin '${requestOrigin}' is not allowed`));
    },
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
  });

  // ── 3b. Serve local uploads statically (fallback for local dev) ──────────
  app.getHttpAdapter().getInstance().use(
    '/uploads',
    express.static(path.join(process.cwd(), 'uploads')),
  );

  // ── 4. Raw WebSocket adapter (compatible with Flutter web_socket_channel) ─
  app.useWebSocketAdapter(new WsAdapter(app));

  // ── 5. Global DTO validation ──────────────────────────────────────────────
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: false, // allow snake_case passthrough fields
      transform: true,
    }),
  );

  // ── 6. Start server ───────────────────────────────────────────────────────
  const port = configService.get<number>('PORT', 3000);
  await app.listen(port);
  console.log(`🚀 Backend running on http://localhost:${port}`);
  console.log(`🔌 WebSocket server ready on ws://localhost:${port}/ws`);
  console.log(`🔐 CORS allowed origins: ${allowedOrigins.join(', ')}`);
}
bootstrap();
