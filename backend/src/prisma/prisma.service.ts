import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import * as crypto from 'crypto';

const ALGORITHM = 'aes-256-cbc';
const ENCRYPTION_KEY =
  process.env.ENCRYPTION_KEY || 'default-secret-key-32-chars-long-x';
const KEY = crypto.scryptSync(ENCRYPTION_KEY, 'salt', 32);
const IV = crypto.scryptSync(ENCRYPTION_KEY, 'iv-salt', 16);

/**
 * Deterministic by design: the IV is derived from the key, not random, so the
 * same plaintext always yields the same ciphertext. That is what allows
 * `where: { email }` lookups to match an encrypted column. It also means this
 * scheme leaks equality — acceptable for lookup columns, not for secrets.
 */
export function encrypt(text: string): string {
  if (!text) return text;
  const cipher = crypto.createCipheriv(ALGORITHM, KEY, IV);
  let encrypted = cipher.update(text, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  return encrypted;
}

export function decrypt(ciphertext: string): string {
  if (!ciphertext) return ciphertext;
  try {
    const decipher = crypto.createDecipheriv(ALGORITHM, KEY, IV);
    let decrypted = decipher.update(ciphertext, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  } catch {
    return ciphertext; // Fallback if not encrypted (e.g. migration phase)
  }
}

/**
 * True only for `{}`-style objects.
 *
 * Traversal must not descend into class instances. A `Date` has no own
 * enumerable properties, so `{ ...date }` is `{}` — spreading one silently
 * destroys every timestamp Prisma returns. The same applies to `Buffer` and
 * `Decimal`. Those are leaf values, not containers.
 */
function isPlainObject(value: unknown): value is Record<string, unknown> {
  if (value === null || typeof value !== 'object') return false;
  const proto: unknown = Object.getPrototypeOf(value);
  return proto === Object.prototype || proto === null;
}

/** A row is a User when it has an id and at least one of the PII columns. */
function looksLikeUserRow(row: Record<string, unknown>): boolean {
  return (
    Boolean(row.id) && (row.email !== undefined || row.phone !== undefined)
  );
}

function decryptField(row: Record<string, unknown>, key: string): void {
  const value = row[key];
  if (typeof value === 'string' && value.length > 0) {
    row[key] = decrypt(value);
  }
}

function decryptValue(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map((entry) => decryptValue(entry));
  }
  if (!isPlainObject(value)) {
    // Primitives, null, Date, Buffer, Decimal — returned untouched.
    return value;
  }

  const row: Record<string, unknown> = { ...value };

  if (looksLikeUserRow(row)) {
    decryptField(row, 'email');
    decryptField(row, 'phone');
    decryptField(row, 'phoneNormalized');
  }

  // Recurse into nested relations (arrays and plain objects only).
  for (const key of Object.keys(row)) {
    row[key] = decryptValue(row[key]);
  }

  return row;
}

/** Recursively decrypt User PII on any value returned by Prisma. */
export function decryptUserPII<T>(obj: T): T {
  return decryptValue(obj) as T;
}

/** The subset of Prisma query arguments this layer rewrites. */
export interface PIIQueryArgs {
  where?: Record<string, unknown>;
  data?: Record<string, unknown>;
  create?: Record<string, unknown>;
  update?: Record<string, unknown>;
}

/** Encrypt `container[key]` when it is a plain string. */
function encryptStringField(
  container: Record<string, unknown>,
  key: string,
): void {
  const value = container[key];
  if (typeof value === 'string') {
    container[key] = encrypt(value);
  }
}

/**
 * Encrypt `container[key]` when it is a string, or every entry of an
 * `{ in: [...] }` filter. Used for the columns that are queried by list —
 * email (login) and phoneNormalized (contact sync).
 */
function encryptStringOrInFilter(
  container: Record<string, unknown>,
  key: string,
): void {
  const value = container[key];
  if (typeof value === 'string') {
    container[key] = encrypt(value);
    return;
  }
  if (isPlainObject(value) && Array.isArray(value.in)) {
    value.in = (value.in as unknown[]).map((entry) =>
      typeof entry === 'string' ? encrypt(entry) : entry,
    );
  }
}

/** Encrypt User PII in query arguments, in place. */
export function encryptUserPIIQueryArgs(
  model: string | undefined,
  args: PIIQueryArgs | undefined | null,
): PIIQueryArgs | undefined | null {
  if (!args) return args;
  if (model !== 'User') return args;

  // 1. Filters in the where clause
  if (args.where) {
    encryptStringOrInFilter(args.where, 'email');
    encryptStringField(args.where, 'phone');
    encryptStringOrInFilter(args.where, 'phoneNormalized');
  }

  // 2. Input data in create/update
  if (args.data) {
    encryptStringField(args.data, 'email');
    encryptStringField(args.data, 'phone');
    encryptStringField(args.data, 'phoneNormalized');
  }

  // 3. Both branches of an upsert
  for (const branch of [args.create, args.update]) {
    if (!branch) continue;
    encryptStringField(branch, 'email');
    encryptStringField(branch, 'phone');
    encryptStringField(branch, 'phoneNormalized');
  }

  return args;
}

/** The delegate methods the soft-delete rewrite reaches for. */
interface ModelDelegate {
  findFirst(args: unknown): Promise<unknown>;
  findFirstOrThrow(args: unknown): Promise<unknown>;
  update(args: unknown): Promise<unknown>;
  updateMany(args: unknown): Promise<unknown>;
}

export type DelegateClient = Record<string, ModelDelegate>;

/** Query arguments as seen by the soft-delete rewrite. */
export interface SoftDeleteArgs {
  where?: Record<string, unknown>;
  data?: Record<string, unknown>;
}

/** Models carrying a `deletedAt` column. */
const SOFT_DELETE_MODELS = [
  'User',
  'Memory',
  'Message',
  'CircleMembership',
  'Comment',
  'Notification',
];

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  private extendedClient!: Record<string | symbol, unknown>;
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    const pool = new Pool({
      connectionString: process.env.DATABASE_URL,
    });
    const adapter = new PrismaPg(pool);
    super({ adapter });

    // An arrow function, not a method: it closes over `this` (the raw instance,
    // not the proxy, which is still in its temporal dead zone here).
    const client = this.$extends({
      query: {
        $allModels: {
          $allOperations: async ({ model, operation, args, query }) => {
            encryptUserPIIQueryArgs(model, args as PIIQueryArgs);
            const result = await this.softDeleteQueryMiddleware(
              model,
              operation,
              args as SoftDeleteArgs,
              query,
              client as unknown as DelegateClient,
            );
            return decryptUserPII(result);
          },
        },
      },
    }) as unknown as Record<string | symbol, unknown>;

    this.extendedClient = client;

    const proxy = new Proxy(this, {
      get: (target, prop, receiver) => {
        const extended = target.extendedClient;
        if (prop in extended) {
          const value = extended[prop];
          if (typeof value === 'function') {
            const fn = value as (...args: unknown[]) => unknown;
            return fn.bind(extended) as unknown;
          }
          return value;
        }
        return Reflect.get(target, prop, receiver) as unknown;
      },
    });
    return proxy;
  }

  async softDeleteQueryMiddleware(
    model: string | undefined,
    operation: string,
    args: SoftDeleteArgs,
    query: (args: unknown) => Promise<unknown>,
    client: DelegateClient,
  ): Promise<unknown> {
    if (!model || !SOFT_DELETE_MODELS.includes(model)) {
      return query(args);
    }

    const modelKey = model.charAt(0).toLowerCase() + model.slice(1);

    if (operation === 'findUnique' || operation === 'findUniqueOrThrow') {
      const whereKeys = Object.keys(args.where ?? {});
      const isCompoundUnique =
        whereKeys.length === 1 && whereKeys[0] === 'unique_user_member';
      if (isCompoundUnique) {
        // Direct query pass-through to let the prisma engine match the unique constraint properly
        return query(args);
      }
      if (operation === 'findUnique') {
        return client[modelKey].findFirst(args);
      }
      return client[modelKey].findFirstOrThrow(args);
    }

    if (
      operation === 'findFirst' ||
      operation === 'findFirstOrThrow' ||
      operation === 'findMany' ||
      operation === 'count'
    ) {
      args.where = args.where ?? {};
      if (args.where.deletedAt === undefined) {
        args.where.deletedAt = null;
      }
    }

    if (operation === 'delete') {
      args.data = { deletedAt: new Date() };
      return client[modelKey].update(args);
    }

    if (operation === 'deleteMany') {
      args.data = args.data ?? {};
      args.data.deletedAt = new Date();
      return client[modelKey].updateMany(args);
    }

    return query(args);
  }

  async onModuleInit() {
    await this.$connect();
    // $connect() with the pg driver adapter is lazy — it does not open a socket
    // or prove the database is reachable, so the app would happily "start" and
    // then 500 every request until Postgres appeared. Force a real round-trip
    // and wait for it, so boot is gated on a database that actually answers.
    await this.waitForDatabase();
  }

  /**
   * Blocks startup until the database answers a trivial query, retrying while
   * it is still coming up (e.g. the Postgres container started after the API).
   * If it never becomes reachable within the budget, throw so the process exits
   * and its supervisor (pm2) restarts it, rather than serving traffic against a
   * dead database.
   */
  private async waitForDatabase(): Promise<void> {
    const maxAttempts = 30;
    const delayMs = 2000;

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await this.$queryRaw`SELECT 1`;
        if (attempt > 1) {
          this.logger.log(`Database reachable after ${attempt} attempts.`);
        }
        return;
      } catch (err) {
        if (attempt === maxAttempts) {
          this.logger.error(
            `Database unreachable after ${maxAttempts} attempts; exiting so the process can restart.`,
          );
          throw err;
        }
        this.logger.warn(
          `Database not ready (attempt ${attempt}/${maxAttempts}); retrying in ${delayMs / 1000}s.`,
        );
        await new Promise((resolve) => setTimeout(resolve, delayMs));
      }
    }
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
