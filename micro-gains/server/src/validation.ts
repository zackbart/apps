// Hand-rolled validation. Settings fail as a whole with a message naming the
// field; sets fail one at a time so a bad row cannot sink a batch.
import { isDateString, isValidTimeZone, localDate, parseInstant } from "./time";
import type { Difficulty, SetLog, SettingsInput } from "./types";

export const DEVICE_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
// Set ids come from UUID v5 of the slot identifier, so any version is accepted.
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const INTERVALS = [60, 90, 120, 180, 240];
const DIFFICULTIES = new Set(["easy", "medium", "hard"]);
const UNITS = new Set(["reps", "seconds"]);
const STATUSES = new Set(["done", "skipped"]);
const SKIP_REASONS = new Set(["bad_time", "too_hard", "not_here"]);
const SOURCES = new Set(["notification", "app"]);

export const MAX_SETS_PER_BATCH = 200;
const DAY_MS = 86_400_000;

export type Validated<T> = { ok: true; value: T } | { ok: false; error: string; message?: string };

export function isDeviceId(value: unknown): value is string {
  return typeof value === "string" && DEVICE_ID.test(value);
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isInt(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value);
}

function invalid(message: string): { ok: false; error: string; message: string } {
  return { ok: false, error: "invalid_settings", message };
}

export function validateSettings(body: unknown, exerciseIds: Set<string>): Validated<SettingsInput> {
  if (!isPlainObject(body)) return invalid("body must be a JSON object");

  const {
    interval_minutes,
    difficulty,
    active_start_minute,
    active_end_minute,
    active_days,
    office_mode,
    floor_ok,
    enabled,
    paused_until,
    exercise_levels,
    timezone,
  } = body;

  if (!isInt(interval_minutes) || !INTERVALS.includes(interval_minutes)) {
    return invalid(`interval_minutes must be one of ${INTERVALS.join(", ")}`);
  }
  if (typeof difficulty !== "string" || !DIFFICULTIES.has(difficulty)) {
    return invalid("difficulty must be easy, medium or hard");
  }
  if (!isInt(active_start_minute) || active_start_minute < 0 || active_start_minute > 1439) {
    return invalid("active_start_minute must be an integer 0..1439");
  }
  if (!isInt(active_end_minute) || active_end_minute < 1 || active_end_minute > 1440) {
    return invalid("active_end_minute must be an integer 1..1440");
  }
  if (active_end_minute <= active_start_minute + interval_minutes) {
    return invalid("active_end_minute must be greater than active_start_minute + interval_minutes");
  }
  // Zero would leave no active day for the streak to anchor to. Pausing is what
  // `enabled` and `paused_until` are for.
  if (!isInt(active_days) || active_days < 1 || active_days > 127) {
    return invalid("active_days must be a 7-bit mask 1..127");
  }
  if (typeof office_mode !== "boolean") return invalid("office_mode must be a boolean");
  if (typeof floor_ok !== "boolean") return invalid("floor_ok must be a boolean");
  if (typeof enabled !== "boolean") return invalid("enabled must be a boolean");

  let pausedUntil: string | null = null;
  if (paused_until !== null && paused_until !== undefined) {
    const parsed = parseInstant(paused_until);
    if (!parsed) return invalid("paused_until must be null or an ISO 8601 timestamp with an offset");
    pausedUntil = parsed.toISOString();
  }

  const levels: Record<string, Difficulty> = {};
  if (exercise_levels !== null && exercise_levels !== undefined) {
    if (!isPlainObject(exercise_levels)) return invalid("exercise_levels must be an object");
    for (const [id, level] of Object.entries(exercise_levels)) {
      if (!exerciseIds.has(id)) return invalid(`exercise_levels has unknown exercise ${id}`);
      if (typeof level !== "string" || !DIFFICULTIES.has(level)) {
        return invalid(`exercise_levels.${id} must be easy, medium or hard`);
      }
      levels[id] = level as Difficulty;
    }
  }

  if (!isValidTimeZone(timezone)) return invalid("timezone must be an IANA time zone name");

  return {
    ok: true,
    value: {
      interval_minutes,
      difficulty: difficulty as Difficulty,
      active_start_minute,
      active_end_minute,
      active_days,
      office_mode,
      floor_ok,
      enabled,
      paused_until: pausedUntil,
      exercise_levels: levels,
      timezone,
    },
  };
}

function reject(error: string): { ok: false; error: string } {
  return { ok: false, error };
}

/**
 * `local_date` is always recomputed from `logged_at` in the device's zone. A
 * client value that disagrees is ignored rather than rejected, per the spec.
 *
 * Every code this returns lands in `rejected[].error` of `POST /api/sets`, so
 * the strings are API and cannot change without a client release. The full set,
 * mirrored in README.md:
 *
 *   invalid_set             the array element is not a JSON object
 *   invalid_id              id is not a UUID
 *   unknown_exercise        exercise_id is not in the catalog
 *   invalid_target          target is not an integer 1..1000
 *   invalid_unit            unit is not reps or seconds
 *   invalid_status          status is not done or skipped
 *   invalid_skip_reason     skipped without a reason in {bad_time, too_hard,
 *                           not_here}, or done with a reason
 *   invalid_source          source is not notification or app
 *   invalid_scheduled_at    scheduled_at is not an ISO 8601 instant with offset
 *   scheduled_at_in_future  scheduled_at is more than a day ahead
 *   invalid_logged_at       logged_at is missing or not an instant with offset
 *   logged_at_in_future     logged_at is more than a day ahead
 *   invalid_local_date      local_date is present and not YYYY-MM-DD
 *
 * The iOS client drops `unknown_exercise` and any `invalid_*` row permanently
 * and retries anything else, so a code that a later attempt could pass, the two
 * `*_in_future` clock-skew cases, must not be named `invalid_*`.
 */
export function validateSet(raw: unknown, exerciseIds: Set<string>, timezone: string, now: Date): Validated<SetLog> {
  if (!isPlainObject(raw)) return reject("invalid_set");
  const id = raw.id;
  if (typeof id !== "string" || !UUID.test(id)) return reject("invalid_id");
  if (typeof raw.exercise_id !== "string" || !exerciseIds.has(raw.exercise_id)) return reject("unknown_exercise");
  if (!isInt(raw.target) || raw.target < 1 || raw.target > 1000) return reject("invalid_target");
  if (typeof raw.unit !== "string" || !UNITS.has(raw.unit)) return reject("invalid_unit");
  if (typeof raw.status !== "string" || !STATUSES.has(raw.status)) return reject("invalid_status");

  // A skipped set must name a reason and a done set must not carry one. Both
  // directions return the same code so the client keys on one string.
  const rawReason = raw.skip_reason ?? null;
  let skipReason: SetLog["skip_reason"] = null;
  if (raw.status === "skipped") {
    if (typeof rawReason !== "string" || !SKIP_REASONS.has(rawReason)) return reject("invalid_skip_reason");
    skipReason = rawReason as SetLog["skip_reason"];
  } else if (rawReason !== null) {
    return reject("invalid_skip_reason");
  }

  if (typeof raw.source !== "string" || !SOURCES.has(raw.source)) return reject("invalid_source");

  const horizon = now.getTime() + DAY_MS;
  let scheduledAt: string | null = null;
  if (raw.scheduled_at !== null && raw.scheduled_at !== undefined) {
    const parsed = parseInstant(raw.scheduled_at);
    if (!parsed) return reject("invalid_scheduled_at");
    if (parsed.getTime() > horizon) return reject("scheduled_at_in_future");
    scheduledAt = raw.scheduled_at as string;
  }

  const loggedAt = parseInstant(raw.logged_at);
  if (!loggedAt) return reject("invalid_logged_at");
  if (loggedAt.getTime() > horizon) return reject("logged_at_in_future");

  if (raw.local_date !== null && raw.local_date !== undefined && !isDateString(raw.local_date)) {
    return reject("invalid_local_date");
  }

  return {
    ok: true,
    value: {
      id: id.toLowerCase(),
      exercise_id: raw.exercise_id,
      target: raw.target,
      unit: raw.unit as SetLog["unit"],
      status: raw.status as SetLog["status"],
      skip_reason: skipReason,
      scheduled_at: scheduledAt,
      logged_at: raw.logged_at as string,
      local_date: localDate(loggedAt, timezone),
      source: raw.source as SetLog["source"],
    },
  };
}

export function validateDays(raw: string | null): Validated<number> {
  if (raw === null) return { ok: true, value: 30 };
  if (!/^\d{1,3}$/.test(raw)) return { ok: false, error: "invalid_days", message: "days must be an integer 1..365" };
  const days = Number(raw);
  if (days < 1 || days > 365) return { ok: false, error: "invalid_days", message: "days must be an integer 1..365" };
  return { ok: true, value: days };
}
