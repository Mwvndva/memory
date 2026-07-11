import './instrument';
import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { ValidationPipe } from '@nestjs/common';
import { WsAdapter } from '@nestjs/platform-ws';
import helmet from 'helmet';
import * as express from 'express';
import * as path from 'path';
import { Logger } from 'nestjs-pino';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    bufferLogs: true,
  });
  app.useLogger(app.get(Logger));
  const configService = app.get(ConfigService);

  // ── 0. Fail fast on unsafe production secrets ───────────────────────────
  //
  // Outside production the refresh secret may fall back to `JWT_SECRET-refresh`
  // (see AuthService.issueTokenPair) so a bare `.env` still boots. In
  // production that fallback is unacceptable: it makes the refresh secret
  // derivable from the access secret, so a single leak compromises both. The
  // previous check accepted the derived value and therefore never fired.
  const MIN_SECRET_LENGTH = 32;
  const jwtSecret = configService.get<string>('JWT_SECRET');
  const refreshSecret = configService.get<string>('REFRESH_TOKEN_SECRET');
  const nodeEnv = configService.get<string>(
    'NODE_ENV',
    process.env.NODE_ENV || 'development',
  );

  if (nodeEnv === 'production') {
    const fatal = (message: string): never => {
      console.error(`FATAL: ${message} Aborting startup in production mode.`);
      process.exit(1);
    };

    if (!jwtSecret || jwtSecret.trim() === '') {
      fatal('JWT_SECRET is not set.');
    } else if (jwtSecret.length < MIN_SECRET_LENGTH) {
      fatal(`JWT_SECRET must be at least ${MIN_SECRET_LENGTH} characters.`);
    }

    if (!refreshSecret || refreshSecret.trim() === '') {
      fatal(
        'REFRESH_TOKEN_SECRET is not set. It must be provided explicitly, not derived from JWT_SECRET.',
      );
    } else if (refreshSecret.length < MIN_SECRET_LENGTH) {
      fatal(
        `REFRESH_TOKEN_SECRET must be at least ${MIN_SECRET_LENGTH} characters.`,
      );
    } else if (refreshSecret === jwtSecret) {
      fatal(
        'REFRESH_TOKEN_SECRET must differ from JWT_SECRET, otherwise a refresh token can be replayed as an access token.',
      );
    }
  }

  // ── 1. Security headers (Helmet) ─────────────────────────────────────────
  app.use(
    helmet({
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    }),
  );

  // ── 2. Trust proxy headers (needed for accurate IP in RateLimitGuard) ────
  const expressApp = app.getHttpAdapter().getInstance() as express.Express;
  expressApp.set('trust proxy', 1);

  // ── 3. CORS — env-driven origin whitelist ────────────────────────────────
  const rawOrigins = configService.get<string>(
    'ALLOWED_ORIGINS',
    'http://localhost:3000,http://localhost:8080',
  );
  const allowedOrigins = rawOrigins
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);

  type CorsCallback = (err: Error | null, allow?: boolean) => void;
  app.enableCors({
    origin: (requestOrigin: string | undefined, callback: CorsCallback) => {
      // No Origin header (same-origin, curl, mobile clients) — always allowed.
      if (!requestOrigin || allowedOrigins.includes(requestOrigin)) {
        callback(null, true);
        return;
      }
      callback(new Error(`CORS: origin '${requestOrigin}' is not allowed`));
    },
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
  });

  // ── 3b. Serve local uploads statically (fallback for local dev) ──────────
  expressApp.use(
    '/uploads',
    express.static(path.join(process.cwd(), 'uploads')),
  );

  // ── 4. Raw WebSocket adapter (compatible with Flutter web_socket_channel) ─
  app.useWebSocketAdapter(new WsAdapter(app));

  // ── 5. Global DTO validation ──────────────────────────────────────────────
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true, // reject any unknown/non-whitelisted parameters
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
// A rejected bootstrap must exit non-zero, not warn and leave a half-started
// process for the orchestrator to treat as healthy.
bootstrap().catch((err) => {
  console.error('FATAL: backend failed to start', err);
  process.exit(1);
});
