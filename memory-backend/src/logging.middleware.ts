import { Injectable, NestMiddleware, Logger } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';

const SENSITIVE_KEYS = ['password', 'token', 'secret', 'jwt', 'authorization'];

/** Only `{}`-style objects are traversed; class instances are leaf values. */
function isPlainObject(value: unknown): value is Record<string, unknown> {
  if (value === null || typeof value !== 'object') return false;
  const proto: unknown = Object.getPrototypeOf(value);
  return proto === Object.prototype || proto === null;
}

/** Redact passwords/tokens from a request body or query before logging it. */
function maskSensitive(value: unknown): unknown {
  if (Array.isArray(value)) return value.map((entry) => maskSensitive(entry));
  if (!isPlainObject(value)) return value;

  const copy: Record<string, unknown> = { ...value };
  for (const key of Object.keys(copy)) {
    if (SENSITIVE_KEYS.some((sk) => key.toLowerCase().includes(sk))) {
      copy[key] = '********';
    } else {
      copy[key] = maskSensitive(copy[key]);
    }
  }
  return copy;
}

@Injectable()
export class LoggingMiddleware implements NestMiddleware {
  private readonly logger = new Logger('HTTP');

  use(req: Request, res: Response, next: NextFunction) {
    const { method, originalUrl, ip } = req;
    const userAgent = req.get('user-agent') || '';
    const startTime = Date.now();

    const maskedBody = maskSensitive(req.body);
    const maskedQuery = maskSensitive(req.query);

    const bodyStr =
      maskedBody &&
      typeof maskedBody === 'object' &&
      Object.keys(maskedBody).length
        ? ` | Body: ${JSON.stringify(maskedBody)}`
        : '';
    const queryStr =
      maskedQuery &&
      typeof maskedQuery === 'object' &&
      Object.keys(maskedQuery).length
        ? ` | Query: ${JSON.stringify(maskedQuery)}`
        : '';

    this.logger.log(
      `--> ${method} ${originalUrl} - IP: ${ip} | UA: ${userAgent}${bodyStr}${queryStr}`,
    );

    res.on('finish', () => {
      const statusCode = res.statusCode;
      const duration = Date.now() - startTime;
      const logMsg = `<-- ${method} ${originalUrl} - ${statusCode} (${duration}ms)`;

      if (statusCode >= 500) {
        this.logger.error(logMsg);
      } else if (statusCode >= 400) {
        this.logger.warn(logMsg);
      } else {
        this.logger.log(logMsg);
      }
    });

    next();
  }
}
