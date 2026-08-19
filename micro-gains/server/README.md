# Micro Gains server

Cloudflare Worker plus D1 behind the Micro Gains iOS app. Plain TypeScript, no
framework, one `fetch` handler in `src/index.ts`. `../SPEC.md` is the contract;
this directory implements the API half of it.

Deployed at **https://micro-gains.onemany.workers.dev** (workers.dev, no custom
domain). D1 database `micro-gains-db`, id `79727aa8-f1f9-4ced-8b70-cefd261619c7`.

The app works offline and syncs when it can, so the server is a store and a
scorekeeper: it holds settings, the set log, and the catalog, and it computes
stats. Scheduling and notifications live entirely on the device.

## Commands

```
npm install
npm run check              # tsc --noEmit
npm test                   # vitest, inside workerd, against a real local D1
npm run db:migrate:local   # apply migrations/ to .wrangler local D1
npm run db:seed:local      # regenerate and re-apply the exercise seed
npm run dev                # wrangler dev on :8788
npm run db:migrate:remote  # apply migrations/ to the production D1
npm run deploy             # migrate remote, then wrangler deploy
```

Tests run through `@cloudflare/vitest-pool-workers`, so every case executes in
the real runtime against local D1 with the committed migrations applied. CHECK
constraints, `ON DELETE CASCADE` and `INSERT OR IGNORE` semantics are all under
test rather than mocked.

## Auth

Every `/api/*` route needs an `X-Device-Id` header holding a lowercase UUID v4.
Anything else is `401 {"error":"device_required"}`. There are no accounts and no
passwords: the app generates the UUID once, keeps it in the Keychain, and
whoever holds it is that device. The server creates the row on first sight and
stamps `last_seen_at` on every authenticated request. `/health` needs no header.

`DELETE /api/me` drops the device row; settings and sets cascade with it.

## Errors

Failures are `{"error":"<snake_case_code>","message"?:string}` with an HTTP
status. Route-level codes: `device_required` (401), `not_found` (404),
`invalid_json` (400), `payload_too_large` (413), `invalid_settings` (400),
`invalid_sets` (400), `invalid_days` (400).

`POST /api/sets` is different. A bad row does not fail the batch; it comes back
in `rejected` as `{"id":<the id sent, or null>,"error":"<code>"}` while the good
rows insert. These are the only values `rejected[].error` takes, and they are
API, so changing one needs a client release:

```
invalid_set             the array element is not a JSON object
invalid_id              id is not a UUID
unknown_exercise        exercise_id is not in the catalog
invalid_target          target is not an integer 1..1000
invalid_unit            unit is not reps or seconds
invalid_status          status is not done or skipped
invalid_skip_reason     skipped without a reason in {bad_time, too_hard,
                        not_here}, or done with a reason
invalid_source          source is not notification or app
invalid_scheduled_at    scheduled_at is not an ISO 8601 instant with an offset
scheduled_at_in_future  scheduled_at is more than a day ahead
invalid_logged_at       logged_at is missing or not an instant with an offset
logged_at_in_future     logged_at is more than a day ahead
invalid_local_date      local_date is present and not YYYY-MM-DD
```

The iOS client drops `unknown_exercise` and every `invalid_*` row from its
outbox for good, and retries everything else. So a code whose row a later
attempt could pass must not be named `invalid_*`: that is why the two clock-skew
cases are `scheduled_at_in_future` and `logged_at_in_future`. Keep the naming
rule when adding a code. The list in `src/validation.ts` above `validateSet`
mirrors this one.

## Layout

```
src/index.ts       router and D1 access
src/validation.ts  hand-rolled field checks for settings and set logs
src/stats.ts       today, totals, current and best streak
src/catalog.ts     catalog rows, sha256 version, ETag matching
src/time.ts        device-local calendar dates via Intl
migrations/        0001 schema, 0002 generated exercise seed
scripts/gen-seed.mjs
```

## Adding or changing an exercise

1. Edit `../catalog.json`. Every exercise needs `intense` alongside the fields
   in SPEC.md; only the four high-intensity cardio items are `true`.
2. `npm run gen:seed` rewrites `migrations/0002_seed_exercises.sql`. Commit it.
   The file is `INSERT OR REPLACE` plus a `DELETE ... WHERE id NOT IN (...)`, so
   re-running it syncs the table rather than appending to it.
3. Applying an edited 0002 needs a new migration, because wrangler records 0002
   as done and will not re-run it. Add `migrations/000N_reseed_exercises.sql`
   holding a copy of the regenerated 0002 body, then `npm run deploy`.
   Locally, `npm run db:seed:local` executes the file directly and skips that
   dance.
4. The catalog `version` is the sha256 of the served JSON, so it changes on its
   own and clients pick the new catalog up on their next `If-None-Match`.

The iOS app bundles the same `catalog.json`. Ship both sides together.

## Notes on the spec

- `active_days` must be 1..127. A zero mask would leave the streak rule with no
  day to anchor to, and `enabled` is the switch for pausing.
- Totals and per-day `reps`/`seconds` count `status = 'done'` rows only. A
  skipped set is not work done.
- `local_date` is always recomputed from `logged_at` in the device's stored
  zone. A disagreeing client value is ignored, not rejected.
- Request bodies are capped at 64 KB for `PUT /api/settings` and 256 KB for
  `POST /api/sets`; a full 200-set batch runs to roughly 50 KB. The cap counts
  UTF-8 bytes, so a body of emoji hits it at a quarter of the character count.
  `Content-Length` is checked first, then the decoded body.
- A device is created with `timezone` `'UTC'`, so `/api/me` on a fresh install
  returns `settings.timezone` `"UTC"` until the first `PUT /api/settings`.
  `Intl.DateTimeFormat` decides what an IANA name is; anything it throws on is
  `invalid_settings`.
- Both streaks are scored against the device's current `active_days` mask, so
  changing the mask re-scores history.
