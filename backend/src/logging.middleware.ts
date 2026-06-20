import { Injectable, NestMiddleware, Logger } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';

@Injectable()
export class LoggingMiddleware implements NestMiddleware {
  private readonly logger = new Logger('HTTP');

  use(req: Request, res: Response, next: NextFunction) {
    const { method, originalUrl, ip } = req;
    const userAgent = req.get('user-agent') || '';
    const startTime = Date.now();

    // Helper to mask sensitive fields (passwords, tokens)
    const maskSensitive = (obj: any): any => {
      if (!obj || typeof obj !== 'object') return obj;
      if (Array.isArray(obj)) return obj.map(maskSensitive);
      const copy = { ...obj };
      const sensitiveKeys = ['password', 'token', 'secret', 'jwt', 'authorization'];
      for (const key of Object.keys(copy)) {
        if (sensitiveKeys.some((sk) => key.toLowerCase().includes(sk))) {
          copy[key] = '********';
        } else if (typeof copy[key] === 'object') {
          copy[key] = maskSensitive(copy[key]);
        }
      }
      return copy;
    };

    const maskedBody = maskSensitive(req.body);
    const maskedQuery = maskSensitive(req.query);

    const bodyStr = (maskedBody && typeof maskedBody === 'object' && Object.keys(maskedBody).length) ? ` | Body: ${JSON.stringify(maskedBody)}` : '';
    const queryStr = (maskedQuery && typeof maskedQuery === 'object' && Object.keys(maskedQuery).length) ? ` | Query: ${JSON.stringify(maskedQuery)}` : '';

    this.logger.log(`--> ${method} ${originalUrl} - IP: ${ip} | UA: ${userAgent}${bodyStr}${queryStr}`);

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
