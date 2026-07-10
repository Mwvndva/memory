require('dotenv/config');

const { defineConfig } = require('prisma/config');

const isTest = !!process.env.TEST_DATABASE_URL;

// Resolved eagerly rather than via prisma's env() helper: env() throws at
// config-load time when the variable is missing, which breaks `prisma generate`
// — a pure codegen step that needs no database. Commands that genuinely need a
// datasource (migrate, db push) still fail loudly below when it is unset.
const datasourceUrl = process.env.TEST_DATABASE_URL || process.env.DATABASE_URL;

module.exports = defineConfig({
  schema: isTest ? 'prisma/schema.test.prisma' : 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
  },
  ...(datasourceUrl ? { datasource: { url: datasourceUrl } } : {}),
});
