/**
 * Typed jest doubles for Prisma model delegates.
 *
 * Specs used to declare `let prisma: any`, which made every
 * `prisma.user.findUnique.mockResolvedValue(...)` an unchecked property access
 * and an unchecked call. Declaring the delegate shape instead keeps the mocks
 * as ergonomic while restoring type checking.
 */
export type MockDelegate = Record<string, jest.Mock>;

/** Build a delegate whose named methods are jest mocks. */
export function delegate(...methods: string[]): MockDelegate {
  const entries = methods.map((name) => [name, jest.fn()] as const);
  return Object.fromEntries(entries);
}

/**
 * Read the nth argument of the nth call to a mock, as [T].
 *
 * `mock.calls` is `any[][]`, so indexing it yields `any`. Asserting the shape at
 * the call site is what keeps the assertion honest and the lint clean.
 */
export function callArg<T>(mock: jest.Mock, callIndex = 0, argIndex = 0): T {
  const calls = mock.mock.calls as unknown[][];
  return calls[callIndex][argIndex] as T;
}

// Jest's asymmetric matchers are declared as `any`. Narrowing them once here
// keeps every assertion that uses them type-checked.

export const anyDate = (): unknown => expect.any(Date) as unknown;

export const anyBuffer = (): unknown => expect.any(Buffer) as unknown;

export const stringContaining = (needle: string): unknown =>
  expect.stringContaining(needle) as unknown;

export const objectContaining = (shape: Record<string, unknown>): unknown =>
  expect.objectContaining(shape) as unknown;
