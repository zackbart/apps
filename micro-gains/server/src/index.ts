import { etagMatches, exerciseIds, loadCatalog } from "./catalog";
import { computeStats, fillDays } from "./stats";
import { addDays, localDate } from "./time";
import { isDeviceId, MAX_SETS_PER_BATCH, validateDays, validateSet, validateSettings } from "./validation";
import type { DayTotals, Difficulty, SetLog, Settings, SettingsInput, Stats } from "./types";

interface Env {
  DB: D1Database;
}

interface DeviceRow {
  id: string;
  created_at: string;
  last_seen_at: string;
  timezone: string;
}

interface SettingsRow {
  interval_minutes: number;
  difficulty: string;
  active_start_minute: number;
  active_end_minute: number;
  active_days: number;
  office_mode: number;
  floor_ok: number;
  enabled: number;
  paused_until: string | null;
  exercise_levels: string;
  updated_at: string;
}

const JSON_HEADERS = { "content-type": "application/json; charset=utf-8" };
const SETTINGS_BODY_LIMIT = 64 * 1024;
// A full 200-set batch runs to roughly 50 KB, so this leaves real headroom
// without letting an unbounded body through.
const SETS_BODY_LIMIT = 256 * 1024;

function json(body: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...JSON_HEADERS, ...headers } });
}

function fail(status: number, error: string, message?: string): Response {
  return json(message === undefined ? { error } : { error, message }, status);
}

async function readJson(request: Request, limit: number): Promise<{ ok: true; value: unknown } | { ok: false; response: Response }> {
  const declared = request.headers.get("content-length");
  if (declared !== null && Number(declared) > limit) {
    return { ok: false, response: fail(413, "payload_too_large", `body must be under ${limit} bytes`) };
  }
  const text = await request.text();
  // Bytes, not UTF-16 units: one emoji is 2 units and 4 bytes, so `.length`
  // would let a body through at up to twice the limit.
  if (new TextEncoder().encode(text).byteLength > limit) {
    return { ok: false, response: fail(413, "payload_too_large", `body must be under ${limit} bytes`) };
  }
  try {
    return { ok: true, value: JSON.parse(text) };
  } catch {
    return { ok: false, response: fail(400, "invalid_json") };
  }
}

/** Creates the device on first sight and stamps last_seen_at on every visit. */
async function touchDevice(db: D1Database, deviceId: string): Promise<DeviceRow> {
  const now = new Date().toISOString();
  const row = await db
    .prepare(
      `INSERT INTO devices (id, created_at, last_seen_at, timezone) VALUES (?1, ?2, ?2, 'UTC')
       ON CONFLICT(id) DO UPDATE SET last_seen_at = excluded.last_seen_at
       RETURNING id, created_at, last_seen_at, timezone`,
    )
    .bind(deviceId, now)
    .first<DeviceRow>();
  if (!row) throw new Error("device upsert returned no row");
  return row;
}

function parseLevels(raw: string): Record<string, Difficulty> {
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? (parsed as Record<string, Difficulty>) : {};
  } catch {
    return {};
  }
}

function toSettings(row: SettingsRow, timezone: string): Settings {
  return {
    interval_minutes: row.interval_minutes,
    difficulty: row.difficulty as Difficulty,
    active_start_minute: row.active_start_minute,
    active_end_minute: row.active_end_minute,
    active_days: row.active_days,
    office_mode: row.office_mode === 1,
    floor_ok: row.floor_ok === 1,
    enabled: row.enabled === 1,
    paused_until: row.paused_until,
    exercise_levels: parseLevels(row.exercise_levels),
    timezone,
    updated_at: row.updated_at,
  };
}

const SELECT_SETTINGS = `SELECT interval_minutes, difficulty, active_start_minute, active_end_minute,
  active_days, office_mode, floor_ok, enabled, paused_until, exercise_levels, updated_at
  FROM settings WHERE device_id = ?`;

/**
 * Materializes the defaults on first read so every device always has settings.
 * updated_at is written here rather than left to the column default, which
 * would be SQLite's "YYYY-MM-DD HH:MM:SS" and not the ISO 8601 clients parse.
 */
async function loadSettings(db: D1Database, device: DeviceRow): Promise<Settings> {
  const [, selected] = await db.batch<SettingsRow>([
    db
      .prepare("INSERT OR IGNORE INTO settings (device_id, updated_at) VALUES (?, ?)")
      .bind(device.id, new Date().toISOString()),
    db.prepare(SELECT_SETTINGS).bind(device.id),
  ]);
  const row = selected?.results?.[0];
  if (!row) throw new Error("settings row missing after insert");
  return toSettings(row, device.timezone);
}

const SELECT_DAY_TOTALS = `SELECT local_date AS date,
    SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) AS done,
    SUM(CASE WHEN status = 'skipped' THEN 1 ELSE 0 END) AS skipped,
    SUM(CASE WHEN status = 'done' AND unit = 'reps' THEN target ELSE 0 END) AS reps,
    SUM(CASE WHEN status = 'done' AND unit = 'seconds' THEN target ELSE 0 END) AS seconds
  FROM sets WHERE device_id = ? GROUP BY local_date ORDER BY local_date`;

async function dayTotals(db: D1Database, deviceId: string): Promise<DayTotals[]> {
  const { results } = await db.prepare(SELECT_DAY_TOTALS).bind(deviceId).all<DayTotals>();
  return results;
}

async function statsFor(db: D1Database, deviceId: string, settings: Settings, now: Date): Promise<Stats> {
  const days = await dayTotals(db, deviceId);
  return computeStats(days, settings.active_days, localDate(now, settings.timezone));
}

async function getCatalog(request: Request, env: Env): Promise<Response> {
  const { exercises, version } = await loadCatalog(env.DB);
  const etag = `"${version}"`;
  if (etagMatches(request.headers.get("if-none-match"), version)) {
    return new Response(null, { status: 304, headers: { etag } });
  }
  return json({ exercises, version }, 200, { etag });
}

async function getMe(env: Env, device: DeviceRow, now: Date): Promise<Response> {
  const settings = await loadSettings(env.DB, device);
  const stats = await statsFor(env.DB, device.id, settings, now);
  return json({ device_id: device.id, settings, stats, created_at: device.created_at });
}

const UPSERT_SETTINGS = `INSERT INTO settings (device_id, interval_minutes, difficulty, active_start_minute,
    active_end_minute, active_days, office_mode, floor_ok, enabled, paused_until, exercise_levels, updated_at)
  VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)
  ON CONFLICT(device_id) DO UPDATE SET
    interval_minutes = excluded.interval_minutes,
    difficulty = excluded.difficulty,
    active_start_minute = excluded.active_start_minute,
    active_end_minute = excluded.active_end_minute,
    active_days = excluded.active_days,
    office_mode = excluded.office_mode,
    floor_ok = excluded.floor_ok,
    enabled = excluded.enabled,
    paused_until = excluded.paused_until,
    exercise_levels = excluded.exercise_levels,
    updated_at = excluded.updated_at`;

function settingsBindings(deviceId: string, input: SettingsInput, updatedAt: string): unknown[] {
  return [
    deviceId,
    input.interval_minutes,
    input.difficulty,
    input.active_start_minute,
    input.active_end_minute,
    input.active_days,
    input.office_mode ? 1 : 0,
    input.floor_ok ? 1 : 0,
    input.enabled ? 1 : 0,
    input.paused_until,
    JSON.stringify(input.exercise_levels),
    updatedAt,
  ];
}

async function putSettings(request: Request, env: Env, device: DeviceRow): Promise<Response> {
  const body = await readJson(request, SETTINGS_BODY_LIMIT);
  if (!body.ok) return body.response;

  const validated = validateSettings(body.value, await exerciseIds(env.DB));
  if (!validated.ok) return fail(400, validated.error, validated.message);

  const updatedAt = new Date().toISOString();
  const input = validated.value;
  await env.DB.batch([
    env.DB.prepare(UPSERT_SETTINGS).bind(...settingsBindings(device.id, input, updatedAt)),
    env.DB.prepare("UPDATE devices SET timezone = ?2 WHERE id = ?1").bind(device.id, input.timezone),
  ]);

  return json({ settings: { ...input, updated_at: updatedAt } satisfies Settings });
}

const INSERT_SET = `INSERT OR IGNORE INTO sets (device_id, id, exercise_id, target, unit, status,
    skip_reason, scheduled_at, logged_at, local_date, source)
  VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)`;

async function postSets(request: Request, env: Env, device: DeviceRow, now: Date): Promise<Response> {
  const body = await readJson(request, SETS_BODY_LIMIT);
  if (!body.ok) return body.response;

  const payload = body.value;
  const rawSets = typeof payload === "object" && payload !== null ? (payload as { sets?: unknown }).sets : undefined;
  if (!Array.isArray(rawSets)) return fail(400, "invalid_sets", "sets must be an array");
  if (rawSets.length < 1 || rawSets.length > MAX_SETS_PER_BATCH) {
    return fail(400, "invalid_sets", `sets must hold 1..${MAX_SETS_PER_BATCH} items`);
  }

  const settings = await loadSettings(env.DB, device);
  const known = await exerciseIds(env.DB);
  const rejected: Array<{ id: unknown; error: string }> = [];
  const accepted: SetLog[] = [];
  const seen = new Set<string>();
  let duplicates = 0;

  for (const raw of rawSets) {
    const validated = validateSet(raw, known, settings.timezone, now);
    if (!validated.ok) {
      const id = typeof raw === "object" && raw !== null ? (raw as { id?: unknown }).id ?? null : null;
      rejected.push({ id, error: validated.error });
      continue;
    }
    // A repeat inside one payload is a duplicate for the same reason a repeat
    // across payloads is: the row already exists by the time we would write it.
    if (seen.has(validated.value.id)) {
      duplicates += 1;
      continue;
    }
    seen.add(validated.value.id);
    accepted.push(validated.value);
  }

  let inserted = 0;
  if (accepted.length > 0) {
    const results = await env.DB.batch(
      accepted.map((set) =>
        env.DB.prepare(INSERT_SET).bind(
          device.id,
          set.id,
          set.exercise_id,
          set.target,
          set.unit,
          set.status,
          set.skip_reason,
          set.scheduled_at,
          set.logged_at,
          set.local_date,
          set.source,
        ),
      ),
    );
    for (const result of results) {
      if ((result.meta?.changes ?? 0) > 0) inserted += 1;
      else duplicates += 1;
    }
  }

  const stats = await statsFor(env.DB, device.id, settings, now);
  return json({ accepted: inserted, duplicates, rejected, stats });
}

async function getHistory(url: URL, env: Env, device: DeviceRow, now: Date): Promise<Response> {
  const requested = validateDays(url.searchParams.get("days"));
  if (!requested.ok) return fail(400, requested.error, requested.message);

  const settings = await loadSettings(env.DB, device);
  const today = localDate(now, settings.timezone);
  const days = await dayTotals(env.DB, device.id);
  return json({
    days: fillDays(days, addDays(today, -(requested.value - 1)), today),
    stats: computeStats(days, settings.active_days, today),
  });
}

async function deleteMe(env: Env, device: DeviceRow): Promise<Response> {
  // settings and sets carry ON DELETE CASCADE, which D1 enforces.
  await env.DB.prepare("DELETE FROM devices WHERE id = ?").bind(device.id).run();
  return new Response(null, { status: 204 });
}

export default {
  async fetch(request, env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    if (path === "/health") {
      if (request.method !== "GET") return fail(404, "not_found");
      try {
        await env.DB.prepare("SELECT 1").first();
        return json({ ok: true, db: true });
      } catch {
        return json({ ok: false, db: false }, 503);
      }
    }

    if (!path.startsWith("/api/")) return fail(404, "not_found");

    const deviceId = request.headers.get("x-device-id");
    if (!isDeviceId(deviceId)) return fail(401, "device_required");

    const now = new Date();
    const device = await touchDevice(env.DB, deviceId);

    if (request.method === "GET" && path === "/api/catalog") return getCatalog(request, env);
    if (request.method === "GET" && path === "/api/me") return getMe(env, device, now);
    if (request.method === "DELETE" && path === "/api/me") return deleteMe(env, device);
    if (request.method === "PUT" && path === "/api/settings") return putSettings(request, env, device);
    if (request.method === "POST" && path === "/api/sets") return postSets(request, env, device, now);
    if (request.method === "GET" && path === "/api/history") return getHistory(url, env, device, now);

    return fail(404, "not_found");
  },
} satisfies ExportedHandler<Env>;
