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

## Production Deployment Safety (Migration Locking)
When deploying this backend to production (e.g. on your VPS or Kubernetes cluster), ensure that database schema migrations are orchestrated carefully:
- **Avoid Concurrent Migrations**: Running multiple application instances concurrently can cause database migration table lock collisions if they all try to execute `npx prisma migrate deploy` simultaneously on startup.
- **Orchestrate Pre-Deploy Stage**: Configure your CI/CD pipeline or deployment environment to run `npx prisma migrate deploy` as a single, isolated pre-deploy stage (or as a Kubernetes init container) *before* triggering the rolling update and scaling up/deploying new backend application instances.

If you want me to adapt the test to a different DB or add tear-down cleanup, tell me which DB you want to use and I will update the scripts accordingly.
