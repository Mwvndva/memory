import { parsePhoneNumberFromString } from 'libphonenumber-js';

const PROTECTED_USERNAME_PREFIXES = [
  'admin',
  'administrator',
  'moderator',
  'support',
  'help',
  'memory',
  'official',
  'system',
  'root',
  'team',
];

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

export function normalizeUsername(username: string): string {
  return username.trim().replace(/^@+/, '').toLowerCase();
}

export function isProtectedUsername(username: string): boolean {
  const clean = normalizeUsername(username);
  return PROTECTED_USERNAME_PREFIXES.some((prefix) => {
    if (clean === prefix) return true;
    if (clean.startsWith(`${prefix}.`)) return true;
    if (clean.startsWith(`${prefix}_`)) return true;
    if (clean.startsWith(`${prefix}-`)) return true;
    if (clean.startsWith(prefix) && clean.length <= prefix.length + 2)
      return true;
    return false;
  });
}

export function normalizePhone(phone: string): string {
  if (!phone) return '';
  const trimmed = phone.trim();
  if (trimmed.startsWith('deleted-') || trimmed.startsWith('del-')) {
    return 'deleted';
  }

  let parsed = parsePhoneNumberFromString(trimmed);
  if (!parsed && !trimmed.startsWith('+')) {
    parsed =
      parsePhoneNumberFromString(trimmed, 'KE') ??
      parsePhoneNumberFromString(trimmed, 'US');
  }

  if (parsed?.isValid()) {
    return parsed.format('E.164');
  }

  const digits = trimmed.replace(/\D/g, '');
  return trimmed.startsWith('+') ? `+${digits}` : digits;
}
