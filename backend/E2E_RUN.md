This folder contains an end-to-end test that validates the full circle request -> accept -> messaging flow.

Prerequisites (on the VPS):

1. Ensure your production/test database is reachable and configured in the environment variable `DATABASE_URL`.
   - For example (bash): export DATABASE_URL="postgresql://user:pass@localhost:5432/memory_test?schema=public"
   - Or set it in your systemd/unit environment.

2. Apply the schema to the DB if not already present:
   - From the `backend` directory run:
     npx prisma db push --schema=./prisma/schema.prisma
   - Or run migrations if you use them.

3. Run the E2E tests:
   - From the `backend` directory run:

     npm run test:e2e

Notes:
- The test will create test users and circle memberships. Use an isolated test database to avoid colliding with production data.
- If you prefer to use a temporary SQLite file, set TEST_DATABASE_URL to a sqlite file and run the test:e2e:sqlite script (Windows users: set env var appropriately for PowerShell).

If you want me to adapt the test to a different DB or add tear-down cleanup, tell me which DB you want to use and I will update the scripts accordingly.
