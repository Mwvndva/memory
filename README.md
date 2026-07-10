# Memory

A social "daily memories" app — capture a short video each day and share it with your
close circle. Flutter client, NestJS backend, real-time WebSockets, and a Cloudflare
worker, built to scale horizontally.

## Architecture

| Layer | Stack |
|-------|-------|
| **Mobile client** | Flutter (`lib/`), Riverpod state, `go_router` |
| **Backend API** | NestJS (`backend/`) — REST + raw WebSocket gateway |
| **Data** | PostgreSQL via Prisma; Redis for cache, sessions, rate limits, pub/sub |
| **Jobs** | BullMQ (Redis-backed) for background/scheduled work |
| **Storage** | Cloudflare R2 (S3-compatible), with local-disk dev fallback |
| **Ops** | Helmet, Sentry, Prometheus metrics, pino logging |
| **Edge** | Cloudflare worker (`cloudflare-worker/`), Firebase (FCM push) |

## Repository layout

```
lib/                 Flutter app
  core/              theme, router, api client, playful UI toolkit
  features/          auth, capture, feed, circle, notification
backend/             NestJS API (see backend/src/*)
  auth/              register, login, refresh, sessions, WS tickets
  users/             profile, avatar, contact sync, GDPR export/erasure
  memories/          feed, single memory, upload, caption edit, delete
  comments/          comments on a memory
  circles/           requests, members, milestones
  messages/          conversation history
  notifications/     history + read state, FCM push, event → content mapping
  gateway/           raw WebSocket gateway
cloudflare-worker/   edge worker
web/ · index.html · app.js · styles.css   web frontend
```

## Getting started

### Backend

```bash
cd backend
cp .env.example .env          # fill in secrets (see below)
docker compose up -d          # Postgres + Redis (backend/docker-compose.yml)
npm install
npx prisma db push            # applies the schema; see "Schema changes" below
npm run start:dev             # http://localhost:3000, ws://localhost:3000/ws
```

Required env (`backend/.env`) — never ship the `.env.example` placeholders:

- `DATABASE_URL` — Postgres connection string.
- `JWT_SECRET` and `REFRESH_TOKEN_SECRET` — **distinct** 32+ character random secrets.
- `REDIS_URL` — Redis connection.
- `ALLOWED_ORIGINS` — comma-separated CORS allowlist (restrict in production).
- `R2_*` — Cloudflare R2 credentials for durable uploads (falls back to local disk).
- `NODE_ENV=production` in prod — startup aborts unless both secrets are set, are
  at least 32 characters, and differ from one another. `REFRESH_TOKEN_SECRET`
  is **not** derived from `JWT_SECRET` in production.

### Schema changes

This project has no migration history — the schema is applied with
`npx prisma db push`, and `npx prisma generate` runs on `postinstall`.
After pulling schema changes (e.g. the `comments` and `notifications` tables),
run `npx prisma db push` before starting the server.

Adopting `prisma migrate` requires baselining the existing tables first; a
`migrations/` directory containing only new migrations would fail on a fresh
database, because `comments` carries a foreign key to a `memories` table that no
migration creates.

### Flutter client

```bash
flutter pub get
flutter run                   # point api_config.dart at your backend
```

## Security

Auth uses Argon2id password hashing with short-lived access tokens (5 min) and rotating
refresh tokens (30 day, JTI allowlist in Redis for per-device revocation). WebSocket
upgrades use one-time, 30-second opaque tickets so no JWT ever hits a loggable header.
Additional hardening: strict DTO validation, per-endpoint rate limiting keyed on the
proxied client IP, magic-byte validation of uploads, HS256-pinned JWTs, public-vs-owner
profile separation (no PII to third parties), and `sanitize-html` on user content.

## Scale & performance

Designed to run as multiple stateless instances behind a load balancer:

- **Caching** — feed, profiles, and single-memory reads are cached in Redis with short
  TTLs and write-through invalidation.
- **Cluster-safe jobs** — rank recalculation, reaction flushing, and message archival
  run as BullMQ repeatable jobs with fixed job IDs (deduplicated across the cluster, so
  each runs once regardless of instance count).
- **Real-time fan-out** — WebSocket events route through a Redis pub/sub bus for
  cross-instance delivery; reaction updates are scoped to a memory's audience rather
  than globally broadcast.

Run behind exactly one reverse proxy (`trust proxy` is set to 1) and front Postgres with
a pooler (e.g. PgBouncer) when scaling out instances.

## UI toolkit

`lib/core/playful.dart` provides dependency-free springy micro-interactions built on
Flutter's native animation framework: `BouncyTap` (press-shrink / release-overshoot),
`PopIn` (elastic entrance), and `showConfetti` (celebratory particle burst). Used across
the feed, auth, capture, and circle screens, and on milestone celebrations.

## Tests

```bash
cd backend && npm test                 # unit
cd backend && npm run test:e2e:sqlite  # e2e against a throwaway SQLite db
flutter test                           # client
```
