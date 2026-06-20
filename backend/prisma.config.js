require('dotenv/config');

const { defineConfig, env } = require('prisma/config');

const isTest = !!process.env.TEST_DATABASE_URL;

module.exports = defineConfig({
  schema: isTest ? 'prisma/schema.test.prisma' : 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
  },
  datasource: {
    url: process.env.TEST_DATABASE_URL || env('DATABASE_URL'),
  },
});
