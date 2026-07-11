/**
 * Extract a printable message from a caught value.
 *
 * `catch (err)` binds `unknown` (or `any`), so `err.message` is an unchecked
 * access on a value that may not be an Error at all — a thrown string, or a
 * rejected non-Error. Funnel every log line through this instead.
 */
export function errorMessage(err: unknown): string {
  if (err instanceof Error) return err.message;
  if (typeof err === 'string') return err;
  try {
    return JSON.stringify(err);
  } catch {
    return String(err);
  }
}

/** Stack trace of a caught value, when it is an Error. */
export function errorStack(err: unknown): string | undefined {
  return err instanceof Error ? err.stack : undefined;
}

/** True when a caught value is a Prisma error carrying `code`. */
export function hasPrismaErrorCode(err: unknown, code: string): boolean {
  return (
    typeof err === 'object' &&
    err !== null &&
    'code' in err &&
    (err as { code?: unknown }).code === code
  );
}
