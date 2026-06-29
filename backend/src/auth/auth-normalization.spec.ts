import {
  isProtectedUsername,
  normalizeEmail,
  normalizePhone,
  normalizeUsername,
} from './auth-normalization';

describe('auth normalization', () => {
  it('normalizes emails before identity lookup or persistence', () => {
    expect(normalizeEmail('  Roy@Example.COM  ')).toBe('roy@example.com');
  });

  it('normalizes usernames before availability checks', () => {
    expect(normalizeUsername('  @@Memory_User  ')).toBe('memory_user');
  });

  it('blocks official-looking usernames', () => {
    expect(isProtectedUsername('memory')).toBe(true);
    expect(isProtectedUsername('memory_official')).toBe(true);
    expect(isProtectedUsername('support1')).toBe(true);
    expect(isProtectedUsername('real_friend')).toBe(false);
  });

  it('normalizes phone numbers to a canonical value where possible', () => {
    expect(normalizePhone('+254 712-345-678')).toBe('+254712345678');
    expect(normalizePhone('0712 345 678')).toBe('+254712345678');
  });
});

