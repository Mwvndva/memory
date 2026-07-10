import type { Request } from 'express';

/**
 * What `JwtStrategy.validate()` attaches to `req.user` on every route guarded
 * by [JwtAuthGuard].
 */
export interface AuthenticatedUser {
  id: string;
  sub: string;
  username: string;
  /**
   * JTI of the refresh session that minted the access token.
   * Absent on tokens issued before the claim was introduced.
   */
  sid?: string;
}

/**
 * Express request on a JwtAuthGuard-protected route.
 *
 * Use this instead of `@Req() req: any`: it is what makes `req.user.id` a
 * checked property access rather than an unsafe one.
 */
export interface AuthenticatedRequest extends Request {
  user: AuthenticatedUser;
}
