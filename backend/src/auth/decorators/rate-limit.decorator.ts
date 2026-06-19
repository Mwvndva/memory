import { SetMetadata } from '@nestjs/common';

export interface RateLimitOptions {
  /** Maximum number of requests allowed in the window. */
  limit: number;
  /** Sliding window duration in seconds. */
  windowSeconds: number;
}

export const RATE_LIMIT_KEY = 'rate_limit';

/**
 * Decorator to attach rate-limit options to a route handler.
 * The RateLimitGuard reads this metadata at runtime.
 *
 * @example
 * \@RateLimit({ limit: 5, windowSeconds: 900 })  // 5 req / 15 min
 * \@Post('login')
 */
export const RateLimit = (options: RateLimitOptions) =>
  SetMetadata(RATE_LIMIT_KEY, options);
