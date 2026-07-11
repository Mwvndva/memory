import {
  decrypt,
  decryptUserPII,
  encrypt,
  encryptUserPIIQueryArgs,
} from '../src/prisma/prisma.service';

describe('PrismaService PII encryption helpers', () => {
  describe('encrypt / decrypt', () => {
    it('round-trips a value', () => {
      expect(decrypt(encrypt('amara@example.com'))).toBe('amara@example.com');
    });

    it('is deterministic, so equality lookups on encrypted columns work', () => {
      expect(encrypt('+254712345678')).toBe(encrypt('+254712345678'));
    });

    it('passes empty values straight through', () => {
      expect(encrypt('')).toBe('');
      expect(decrypt('')).toBe('');
    });

    it('returns plaintext unchanged when it is not ciphertext (migration phase)', () => {
      expect(decrypt('not-encrypted-at-all')).toBe('not-encrypted-at-all');
    });
  });

  describe('decryptUserPII', () => {
    it('decrypts email, phone and phoneNormalized on a user row', () => {
      const row = {
        id: 'u-1',
        email: encrypt('amara@example.com'),
        phone: encrypt('+254712345678'),
        phoneNormalized: encrypt('+254712345678'),
      };

      expect(decryptUserPII(row)).toEqual({
        id: 'u-1',
        email: 'amara@example.com',
        phone: '+254712345678',
        phoneNormalized: '+254712345678',
      });
    });

    it('recurses into arrays and nested relations', () => {
      const rows = [
        {
          id: 'm-1',
          caption: 'hi',
          creator: { id: 'u-1', email: encrypt('a@b.com'), phone: null },
        },
      ];

      const out = decryptUserPII(rows);
      expect(out[0].creator.email).toBe('a@b.com');
    });

    it('leaves rows that are not users alone', () => {
      const row = { id: 'r-1', emoji: '🔥', count: 3 };
      expect(decryptUserPII(row)).toEqual(row);
    });

    // Regression: `{...new Date()}` is `{}` — a Date has no own enumerable
    // properties. Every Prisma result passes through this function, so spreading
    // Dates silently replaced every timestamp with an empty object, and
    // `createdAt.toISOString()` in the feed would throw.
    it('preserves Date fields instead of flattening them', () => {
      const createdAt = new Date('2026-07-01T12:00:00.000Z');
      const row = { id: 'm-1', caption: 'hi', createdAt };

      const out = decryptUserPII(row) as { createdAt: Date };

      expect(out.createdAt).toBeInstanceOf(Date);
      expect(out.createdAt.toISOString()).toBe('2026-07-01T12:00:00.000Z');
    });

    it('preserves Dates nested inside relations and arrays', () => {
      const createdAt = new Date('2026-07-01T12:00:00.000Z');
      const rows = [
        {
          id: 'm-1',
          createdAt,
          creator: { id: 'u-1', email: encrypt('a@b.com'), createdAt },
        },
      ];

      const out = decryptUserPII(rows) as Array<{
        createdAt: Date;
        creator: { createdAt: Date; email: string };
      }>;

      expect(out[0].createdAt).toBeInstanceOf(Date);
      expect(out[0].creator.createdAt).toBeInstanceOf(Date);
      expect(out[0].creator.email).toBe('a@b.com');
    });

    it('preserves null fields', () => {
      const row = { id: 'u-1', email: encrypt('a@b.com'), avatarUrl: null };
      expect((decryptUserPII(row) as { avatarUrl: null }).avatarUrl).toBeNull();
    });
  });

  describe('encryptUserPIIQueryArgs', () => {
    it('encrypts a where filter on email', () => {
      const args = { where: { email: 'amara@example.com' } };
      encryptUserPIIQueryArgs('User', args);
      expect(args.where.email).toBe(encrypt('amara@example.com'));
    });

    it('encrypts every value of a where { email: { in: [...] } } filter', () => {
      const args = { where: { email: { in: ['a@b.com', 'c@d.com'] } } };
      encryptUserPIIQueryArgs('User', args);
      expect(args.where.email.in).toEqual([
        encrypt('a@b.com'),
        encrypt('c@d.com'),
      ]);
    });

    it('encrypts phoneNormalized in lists — the contact-sync path', () => {
      const args = { where: { phoneNormalized: { in: ['+254712345678'] } } };
      encryptUserPIIQueryArgs('User', args);
      expect(args.where.phoneNormalized.in).toEqual([encrypt('+254712345678')]);
    });

    it('encrypts create/update data', () => {
      const args = { data: { email: 'a@b.com', phone: '+1', other: 'keep' } };
      encryptUserPIIQueryArgs('User', args);
      expect(args.data.email).toBe(encrypt('a@b.com'));
      expect(args.data.phone).toBe(encrypt('+1'));
      expect(args.data.other).toBe('keep');
    });

    it('encrypts both branches of an upsert', () => {
      const args = {
        create: { email: 'a@b.com' },
        update: { phone: '+1' },
      };
      encryptUserPIIQueryArgs('User', args);
      expect(args.create.email).toBe(encrypt('a@b.com'));
      expect(args.update.phone).toBe(encrypt('+1'));
    });

    it('ignores models other than User', () => {
      const args = { where: { email: 'a@b.com' } };
      encryptUserPIIQueryArgs('Memory', args);
      expect(args.where.email).toBe('a@b.com');
    });

    it('tolerates absent args', () => {
      expect(() => encryptUserPIIQueryArgs('User', undefined)).not.toThrow();
    });
  });
});
