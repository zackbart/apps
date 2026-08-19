import type { D1Migration } from "@cloudflare/vitest-pool-workers";

declare global {
  namespace Cloudflare {
    interface Env {
      DB: D1Database;
      // Read from migrations/ in vitest.config.ts, applied by test setup.
      TEST_MIGRATIONS: D1Migration[];
    }
  }
}

export {};
