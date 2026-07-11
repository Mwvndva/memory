import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/**
 * Protects endpoints that require a valid refresh token.
 * Uses the 'jwt-refresh' Passport strategy which validates:
 *  - JWT signature (REFRESH_TOKEN_SECRET)
 *  - tokenType === 'refresh' claim
 *  - JTI presence in the Redis allowlist
 */
@Injectable()
export class JwtRefreshGuard extends AuthGuard('jwt-refresh') {}
