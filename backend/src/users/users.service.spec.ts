import { Test, TestingModule } from '@nestjs/testing';
import { UsersService } from './users.service';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';

/**
 * The phone backfill runs at boot, before anything guarantees the database is
 * up. Under pm2 the API can outrun the Postgres container, so the first query
 * fails with P1001 "can't reach database server". These tests pin the retry
 * behaviour that keeps that transient condition from logging an error and
 * skipping the backfill for the whole boot.
 */
describe('UsersService boot-time backfill resilience', () => {
  let service: UsersService;

  // Reaches the private retry loop and the injected logger without `any`.
  interface Internals {
    runBackfillWhenReady: () => Promise<void>;
    logger: {
      warn: (...a: unknown[]) => void;
      error: (...a: unknown[]) => void;
    };
  }
  const internals = () => service as unknown as Internals;

  beforeEach(async () => {
    // The backfill itself is spied per-test, so Prisma/Redis are never touched.
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: PrismaService, useValue: {} },
        { provide: RedisService, useValue: {} },
      ],
    }).compile();
    service = module.get<UsersService>(UsersService);
  });

  afterEach(() => {
    jest.useRealTimers();
    jest.restoreAllMocks();
  });

  it('waits out a database that is not ready, then completes without escalating', async () => {
    jest.useFakeTimers();
    const unreachable = Object.assign(
      new Error("Can't reach database server at 127.0.0.1:5435"),
      { errorCode: 'P1001' },
    );
    const backfill = jest
      .spyOn(service, 'backfillNormalizedPhones')
      .mockRejectedValueOnce(unreachable)
      .mockResolvedValueOnce(undefined);
    const warn = jest
      .spyOn(internals().logger, 'warn')
      .mockImplementation(() => {});
    const error = jest
      .spyOn(internals().logger, 'error')
      .mockImplementation(() => {});

    const done = internals().runBackfillWhenReady();
    await jest.advanceTimersByTimeAsync(3000); // first backoff window
    await done;

    expect(backfill).toHaveBeenCalledTimes(2);
    expect(warn).toHaveBeenCalledTimes(1);
    expect(error).not.toHaveBeenCalled();
  });

  it('detects an unreachable database from the message alone, with no error code', async () => {
    jest.useFakeTimers();
    const backfill = jest
      .spyOn(service, 'backfillNormalizedPhones')
      // No errorCode — only the P1001 message. The fallback must still retry.
      .mockRejectedValueOnce(
        new Error("Can't reach database server at 127.0.0.1:5435"),
      )
      .mockResolvedValueOnce(undefined);
    const error = jest
      .spyOn(internals().logger, 'error')
      .mockImplementation(() => {});

    const done = internals().runBackfillWhenReady();
    await jest.advanceTimersByTimeAsync(3000);
    await done;

    expect(backfill).toHaveBeenCalledTimes(2);
    expect(error).not.toHaveBeenCalled();
  });

  it('escalates a real query error immediately, without retrying', async () => {
    const backfill = jest
      .spyOn(service, 'backfillNormalizedPhones')
      .mockRejectedValue(new Error('column "phone_normalized" does not exist'));
    const error = jest
      .spyOn(internals().logger, 'error')
      .mockImplementation(() => {});

    await internals().runBackfillWhenReady();

    expect(backfill).toHaveBeenCalledTimes(1);
    expect(error).toHaveBeenCalledTimes(1);
  });
});
