import { SELF, env } from "cloudflare:test";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const ORIGIN = "https://micro-gains.test";
// Fixed clock so streak fixtures are dates and not arithmetic. 2026-08-19 is a
// Wednesday; 11:30Z on that day is 23:30 the same day in Auckland.
const NOW = "2026-08-19T18:00:00Z";
const WEEKDAYS = 0b0011111;

const defaultSettings = {
  interval_minutes: 120,
  difficulty: "medium",
  active_start_minute: 540,
  active_end_minute: 1140,
  active_days: 127,
  office_mode: false,
  floor_ok: true,
  enabled: true,
  paused_until: null,
  exercise_levels: {},
  timezone: "America/Los_Angeles",
};

function newDevice(): string {
  return crypto.randomUUID();
}

function call(path: string, deviceId: string | null, init: RequestInit = {}): Promise<Response> {
  const headers = new Headers(init.headers);
  if (deviceId !== null) headers.set("x-device-id", deviceId);
  if (init.body !== undefined) headers.set("content-type", "application/json");
  return SELF.fetch(`${ORIGIN}${path}`, { ...init, headers });
}

function put(path: string, deviceId: string, body: unknown): Promise<Response> {
  return call(path, deviceId, { method: "PUT", body: JSON.stringify(body) });
}

function post(path: string, deviceId: string, body: unknown): Promise<Response> {
  return call(path, deviceId, { method: "POST", body: JSON.stringify(body) });
}

/**
 * Sends the body as a stream, which carries no Content-Length. That skips the
 * header precheck in readJson and leaves the decoded body as the only thing
 * measured, which is the branch the byte-counting tests are aiming at.
 */
function streamCall(path: string, deviceId: string, method: string, body: string): Promise<Response> {
  const bytes = new TextEncoder().encode(body);
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(bytes);
      controller.close();
    },
  });
  return SELF.fetch(
    new Request(`${ORIGIN}${path}`, {
      method,
      headers: { "x-device-id": deviceId, "content-type": "application/json" },
      body: stream,
    }),
  );
}

function aSet(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: crypto.randomUUID(),
    exercise_id: "air_squat",
    target: 15,
    unit: "reps",
    status: "done",
    skip_reason: null,
    scheduled_at: "2026-08-19T10:00:00-07:00",
    logged_at: "2026-08-19T10:02:00-07:00",
    local_date: "2026-08-19",
    source: "notification",
  };
}

function setOn(date: string, overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return { ...aSet(), logged_at: `${date}T10:02:00-07:00`, scheduled_at: `${date}T10:00:00-07:00`, local_date: date, ...overrides };
}

beforeEach(() => {
  // Only Date is faked: faking setTimeout would stall the workerd event loop.
  vi.useFakeTimers({ toFake: ["Date"] });
  vi.setSystemTime(new Date(NOW));
});

afterEach(() => {
  vi.useRealTimers();
});

describe("GET /health", () => {
  it("reports the D1 probe", async () => {
    const response = await SELF.fetch(`${ORIGIN}/health`);
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ ok: true, db: true });
  });

  it("needs no device header", async () => {
    expect((await SELF.fetch(`${ORIGIN}/health`)).status).toBe(200);
  });
});

describe("auth", () => {
  const cases: Array<[string, string | null]> = [
    ["missing", null],
    ["not a uuid", "nope"],
    ["uppercase", "5F2C9B1E-1D3A-4A6B-9C2E-7A1B2C3D4E5F".toUpperCase()],
    ["uuid v1", "3d813cbb-47fb-11e9-8b2d-1b9d6bcdbbfd"],
    ["empty", ""],
  ];

  for (const [label, deviceId] of cases) {
    it(`rejects a ${label} device id with 401`, async () => {
      const response = await call("/api/me", deviceId);
      expect(response.status).toBe(401);
      expect(await response.json()).toEqual({ error: "device_required" });
    });
  }

  it("guards every /api route", async () => {
    for (const path of ["/api/catalog", "/api/me", "/api/settings", "/api/sets", "/api/history"]) {
      expect((await call(path, null)).status).toBe(401);
    }
  });

  it("stamps last_seen_at on every call", async () => {
    const device = newDevice();
    await call("/api/me", device);
    const first = await env.DB.prepare("SELECT last_seen_at FROM devices WHERE id = ?").bind(device).first<{ last_seen_at: string }>();

    vi.setSystemTime(new Date("2026-08-20T18:00:00Z"));
    await call("/api/catalog", device);
    const second = await env.DB.prepare("SELECT last_seen_at FROM devices WHERE id = ?").bind(device).first<{ last_seen_at: string }>();

    expect(second?.last_seen_at).not.toBe(first?.last_seen_at);
    expect(second?.last_seen_at).toBe("2026-08-20T18:00:00.000Z");
  });
});

describe("routing", () => {
  it("404s an unknown path", async () => {
    const response = await call("/api/nope", newDevice());
    expect(response.status).toBe(404);
    expect(await response.json()).toEqual({ error: "not_found" });
  });

  it("404s an unknown path outside /api without a device", async () => {
    const response = await SELF.fetch(`${ORIGIN}/`);
    expect(response.status).toBe(404);
    expect(await response.json()).toEqual({ error: "not_found" });
  });

  it("404s the wrong method on a known path", async () => {
    expect((await post("/api/catalog", newDevice(), {})).status).toBe(404);
  });
});

describe("GET /api/catalog", () => {
  it("serves the seeded catalog with a version", async () => {
    const response = await call("/api/catalog", newDevice());
    expect(response.status).toBe(200);
    const body = await response.json<{ exercises: Array<Record<string, unknown>>; version: string }>();
    expect(body.exercises).toHaveLength(30);
    expect(body.version).toMatch(/^[0-9a-f]{64}$/);
    expect(response.headers.get("etag")).toBe(`"${body.version}"`);

    const first = body.exercises[0];
    expect(first).toEqual({
      id: "wall_pushup",
      name: "Wall push-up",
      pattern: "push",
      unit: "reps",
      easy: 10,
      medium: 18,
      hard: 28,
      cue: "Body straight, elbows back at 45 degrees, chest to wall",
      office_ok: true,
      needs_floor: false,
      intense: false,
    });
    expect(body.exercises.filter((exercise) => exercise.intense === true).map((exercise) => exercise.id)).toEqual([
      "step_jacks",
      "jumping_jacks",
      "high_knees",
      "stair_climb",
    ]);
  });

  it("keeps catalog order stable", async () => {
    const body = await (await call("/api/catalog", newDevice())).json<{ exercises: Array<{ id: string }> }>();
    expect(body.exercises.at(-1)?.id).toBe("half_kneeling_hip_flexor");
  });

  it("answers If-None-Match with 304 and no body", async () => {
    const device = newDevice();
    const first = await call("/api/catalog", device);
    const version = (await first.json<{ version: string }>()).version;

    for (const header of [version, `"${version}"`, `W/"${version}"`, `"other", "${version}"`]) {
      const response = await call("/api/catalog", device, { headers: { "if-none-match": header } });
      expect(response.status).toBe(304);
      expect(await response.text()).toBe("");
      expect(response.headers.get("etag")).toBe(`"${version}"`);
    }
  });

  it("serves a body again when the version does not match", async () => {
    const response = await call("/api/catalog", newDevice(), { headers: { "if-none-match": '"stale"' } });
    expect(response.status).toBe(200);
  });
});

describe("GET /api/me", () => {
  it("creates the device with defaults", async () => {
    const device = newDevice();
    const response = await call("/api/me", device);
    expect(response.status).toBe(200);
    const body = await response.json<{ device_id: string; settings: Record<string, unknown>; stats: Record<string, number>; created_at: string }>();

    expect(body.device_id).toBe(device);
    expect(body.created_at).toBe("2026-08-19T18:00:00.000Z");
    expect(body.settings).toEqual({
      interval_minutes: 120,
      difficulty: "medium",
      active_start_minute: 540,
      active_end_minute: 1140,
      active_days: 127,
      office_mode: false,
      floor_ok: true,
      enabled: true,
      paused_until: null,
      exercise_levels: {},
      timezone: "UTC",
      updated_at: "2026-08-19T18:00:00.000Z",
    });
    expect(body.stats).toEqual({
      today_done: 0,
      today_skipped: 0,
      streak_days: 0,
      best_streak_days: 0,
      total_done: 0,
      total_reps: 0,
      total_seconds: 0,
    });
  });

  it("starts a brand new device on UTC", async () => {
    const device = newDevice();
    const body = await (await call("/api/me", device)).json<{ settings: { timezone: string } }>();
    expect(body.settings.timezone).toBe("UTC");

    const row = await env.DB.prepare("SELECT timezone FROM devices WHERE id = ?").bind(device).first<{ timezone: string }>();
    expect(row?.timezone).toBe("UTC");

    // Still UTC on a second read, and the day is scored in UTC until a PUT
    // says otherwise: 18:00Z on the 19th is the 19th, not the 18th.
    const again = await (await call("/api/me", device)).json<{ settings: { timezone: string } }>();
    expect(again.settings.timezone).toBe("UTC");
  });

  it("keeps created_at across calls", async () => {
    const device = newDevice();
    const first = await (await call("/api/me", device)).json<{ created_at: string }>();
    vi.setSystemTime(new Date("2026-08-21T18:00:00Z"));
    const second = await (await call("/api/me", device)).json<{ created_at: string }>();
    expect(second.created_at).toBe(first.created_at);
  });
});

describe("PUT /api/settings", () => {
  it("writes settings and the device time zone", async () => {
    const device = newDevice();
    const response = await put("/api/settings", device, {
      ...defaultSettings,
      interval_minutes: 90,
      difficulty: "hard",
      active_days: WEEKDAYS,
      office_mode: true,
      paused_until: "2026-08-20T09:00:00-07:00",
      exercise_levels: { full_pushup: "easy" },
    });

    expect(response.status).toBe(200);
    const body = await response.json<{ settings: Record<string, unknown> }>();
    expect(body.settings.interval_minutes).toBe(90);
    expect(body.settings.difficulty).toBe("hard");
    expect(body.settings.office_mode).toBe(true);
    expect(body.settings.exercise_levels).toEqual({ full_pushup: "easy" });
    expect(body.settings.paused_until).toBe("2026-08-20T16:00:00.000Z");
    expect(body.settings.updated_at).toBe("2026-08-19T18:00:00.000Z");

    const row = await env.DB.prepare("SELECT timezone FROM devices WHERE id = ?").bind(device).first<{ timezone: string }>();
    expect(row?.timezone).toBe("America/Los_Angeles");

    const reread = await (await call("/api/me", device)).json<{ settings: Record<string, unknown> }>();
    expect(reread.settings).toEqual(body.settings);
  });

  const invalid: Array<[string, Record<string, unknown>]> = [
    ["an unlisted interval", { interval_minutes: 45 }],
    ["a non-integer interval", { interval_minutes: 90.5 }],
    ["a window narrower than one interval", { active_start_minute: 540, active_end_minute: 660 }],
    ["a window shorter than the interval", { active_start_minute: 540, active_end_minute: 600 }],
    ["an end before the start", { active_start_minute: 900, active_end_minute: 480 }],
    ["a start past midnight", { active_start_minute: 1500 }],
    ["a mask above 7 bits", { active_days: 128 }],
    ["an empty mask", { active_days: 0 }],
    ["a negative mask", { active_days: -1 }],
    ["a non-integer mask", { active_days: 3.5 }],
    ["an unknown difficulty", { difficulty: "brutal" }],
    ["a string boolean", { office_mode: "true" }],
    ["a missing field", { enabled: undefined }],
    ["an unknown exercise override", { exercise_levels: { moon_walk: "easy" } }],
    ["a bad level in an override", { exercise_levels: { air_squat: "brutal" } }],
    ["a bogus time zone", { timezone: "Mars/Olympus" }],
    ["a time zone Intl does not know", { timezone: "America/Atlantis" }],
    ["a missing time zone", { timezone: undefined }],
    ["a null time zone", { timezone: null }],
    ["an empty time zone", { timezone: "" }],
    ["a non-string time zone", { timezone: 42 }],
    ["a time zone with a trailing space", { timezone: "America/Los_Angeles " }],
    ["an absurdly long time zone", { timezone: `America/${"x".repeat(120)}` }],
    ["a non-ISO paused_until", { paused_until: "tomorrow" }],
    ["a paused_until without an offset", { paused_until: "2026-08-20T09:00:00" }],
  ];

  for (const [label, patch] of invalid) {
    it(`rejects ${label}`, async () => {
      const body: Record<string, unknown> = { ...defaultSettings, ...patch };
      for (const [key, value] of Object.entries(patch)) if (value === undefined) delete body[key];
      const response = await put("/api/settings", newDevice(), body);
      expect(response.status).toBe(400);
      const payload = await response.json<{ error: string; message: string }>();
      expect(payload.error).toBe("invalid_settings");
      expect(payload.message).toBeTruthy();
    });
  }

  it("accepts a window exactly one minute wider than the interval", async () => {
    const response = await put("/api/settings", newDevice(), {
      ...defaultSettings,
      interval_minutes: 60,
      active_start_minute: 540,
      active_end_minute: 601,
    });
    expect(response.status).toBe(200);
  });

  it("rejects a body that is not JSON", async () => {
    const response = await call("/api/settings", newDevice(), { method: "PUT", body: "{oops" });
    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "invalid_json" });
  });

  it("rejects an empty body", async () => {
    const response = await call("/api/settings", newDevice(), { method: "PUT", body: "" });
    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "invalid_json" });
  });

  it("rejects a JSON array", async () => {
    const response = await put("/api/settings", newDevice(), [1, 2, 3]);
    expect(response.status).toBe(400);
    expect((await response.json<{ error: string }>()).error).toBe("invalid_settings");
  });

  it("rejects a body over 64 KB", async () => {
    const response = await put("/api/settings", newDevice(), { ...defaultSettings, junk: "x".repeat(70_000) });
    expect(response.status).toBe(413);
    expect((await response.json<{ error: string }>()).error).toBe("payload_too_large");
  });

  it("measures the body limit in UTF-8 bytes, not UTF-16 units", async () => {
    // 20k emoji is 40k UTF-16 units, comfortably under 65536 by `.length`, but
    // 80 KB on the wire. Counting characters would let it through.
    const body = JSON.stringify({ ...defaultSettings, junk: "\u{1F600}".repeat(20_000) });
    expect(body.length).toBeLessThan(64 * 1024);
    expect(new TextEncoder().encode(body).byteLength).toBeGreaterThan(64 * 1024);

    const response = await streamCall("/api/settings", newDevice(), "PUT", body);
    expect(response.status).toBe(413);
    expect((await response.json<{ error: string }>()).error).toBe("payload_too_large");
  });

  it("takes a multibyte body that fits the limit", async () => {
    const body = JSON.stringify({ ...defaultSettings, junk: "\u{1F600}".repeat(1_000) });
    expect(new TextEncoder().encode(body).byteLength).toBeLessThan(64 * 1024);
    const response = await streamCall("/api/settings", newDevice(), "PUT", body);
    expect(response.status).toBe(200);
  });

  it("takes real but unusual IANA zones", async () => {
    for (const timezone of ["UTC", "Etc/GMT+5", "Pacific/Chatham", "Asia/Kolkata"]) {
      const response = await put("/api/settings", newDevice(), { ...defaultSettings, timezone });
      expect([timezone, response.status]).toEqual([timezone, 200]);
    }
  });

  it("leaves the stored zone alone when a bogus zone is rejected", async () => {
    const device = newDevice();
    await put("/api/settings", device, defaultSettings);
    const response = await put("/api/settings", device, { ...defaultSettings, timezone: "Mars/Olympus" });
    expect(response.status).toBe(400);
    expect((await response.json<{ error: string }>()).error).toBe("invalid_settings");

    const row = await env.DB.prepare("SELECT timezone FROM devices WHERE id = ?").bind(device).first<{ timezone: string }>();
    expect(row?.timezone).toBe("America/Los_Angeles");
  });
});

describe("POST /api/sets", () => {
  it("accepts a batch and returns fresh stats", async () => {
    const device = newDevice();
    await put("/api/settings", device, defaultSettings);
    const response = await post("/api/sets", device, {
      sets: [aSet(), { ...aSet(), exercise_id: "forearm_plank", unit: "seconds", target: 45 }],
    });

    expect(response.status).toBe(200);
    const body = await response.json<{ accepted: number; duplicates: number; rejected: unknown[]; stats: Record<string, number> }>();
    expect(body).toMatchObject({ accepted: 2, duplicates: 0, rejected: [] });
    expect(body.stats).toEqual({
      today_done: 2,
      today_skipped: 0,
      streak_days: 1,
      best_streak_days: 1,
      total_done: 2,
      total_reps: 15,
      total_seconds: 45,
    });
  });

  it("counts a replayed batch as duplicates", async () => {
    const device = newDevice();
    await put("/api/settings", device, defaultSettings);
    const sets = [aSet(), aSet()];

    const first = await (await post("/api/sets", device, { sets })).json<{ accepted: number; duplicates: number }>();
    expect(first).toMatchObject({ accepted: 2, duplicates: 0 });

    const second = await (await post("/api/sets", device, { sets })).json<{ accepted: number; duplicates: number; stats: Record<string, number> }>();
    expect(second).toMatchObject({ accepted: 0, duplicates: 2 });
    expect(second.stats.total_done).toBe(2);
  });

  it("collapses a repeat inside one payload", async () => {
    const device = newDevice();
    const set = aSet();
    const body = await (await post("/api/sets", device, { sets: [set, set] })).json<{ accepted: number; duplicates: number }>();
    expect(body).toMatchObject({ accepted: 1, duplicates: 1 });
  });

  it("scopes idempotency to the device", async () => {
    const set = aSet();
    const one = await (await post("/api/sets", newDevice(), { sets: [set] })).json<{ accepted: number }>();
    const two = await (await post("/api/sets", newDevice(), { sets: [set] })).json<{ accepted: number }>();
    expect(one.accepted).toBe(1);
    expect(two.accepted).toBe(1);
  });

  it("records skips with a reason", async () => {
    const device = newDevice();
    const body = await (
      await post("/api/sets", device, {
        sets: [aSet(), { ...aSet(), status: "skipped", skip_reason: "too_hard", source: "app" }],
      })
    ).json<{ accepted: number; stats: Record<string, number> }>();
    expect(body.accepted).toBe(2);
    expect(body.stats.today_done).toBe(1);
    expect(body.stats.today_skipped).toBe(1);
    expect(body.stats.total_reps).toBe(15);
  });

  it("takes every skip reason and stores it", async () => {
    const device = newDevice();
    const sets = ["bad_time", "too_hard", "not_here"].map((skip_reason) => ({ ...aSet(), status: "skipped", skip_reason }));
    const body = await (await post("/api/sets", device, { sets })).json<{ accepted: number; rejected: unknown[] }>();
    expect(body.accepted).toBe(3);
    expect(body.rejected).toEqual([]);

    const { results } = await env.DB.prepare("SELECT skip_reason FROM sets WHERE device_id = ? ORDER BY skip_reason")
      .bind(device)
      .all<{ skip_reason: string }>();
    expect(results.map((row) => row.skip_reason)).toEqual(["bad_time", "not_here", "too_hard"]);
  });

  it("stores null skip_reason for a done set that omits the key", async () => {
    const device = newDevice();
    const set: Record<string, unknown> = { ...aSet() };
    delete set.skip_reason;
    const body = await (await post("/api/sets", device, { sets: [set] })).json<{ accepted: number }>();
    expect(body.accepted).toBe(1);

    const row = await env.DB.prepare("SELECT skip_reason FROM sets WHERE device_id = ? AND id = ?")
      .bind(device, set.id)
      .first<{ skip_reason: string | null }>();
    expect(row?.skip_reason).toBeNull();
  });

  const badSets: Array<[string, Record<string, unknown>, string]> = [
    ["an unknown exercise", { exercise_id: "moon_walk" }, "unknown_exercise"],
    ["a zero target", { target: 0 }, "invalid_target"],
    ["a target over 1000", { target: 1001 }, "invalid_target"],
    ["a fractional target", { target: 12.5 }, "invalid_target"],
    ["a bad unit", { unit: "miles" }, "invalid_unit"],
    ["a bad status", { status: "maybe" }, "invalid_status"],
    ["a bad source", { source: "watch" }, "invalid_source"],
    ["a bad skip reason", { status: "skipped", skip_reason: "meh" }, "invalid_skip_reason"],
    ["a skip reason on a done set", { status: "done", skip_reason: "bad_time" }, "invalid_skip_reason"],
    ["a skipped set with a null reason", { status: "skipped", skip_reason: null }, "invalid_skip_reason"],
    ["a skipped set with no reason key", { status: "skipped", skip_reason: undefined }, "invalid_skip_reason"],
    ["a skipped set with an empty reason", { status: "skipped", skip_reason: "" }, "invalid_skip_reason"],
    ["a skipped set with a non-string reason", { status: "skipped", skip_reason: 3 }, "invalid_skip_reason"],
    ["a logged_at without an offset", { logged_at: "2026-08-19T10:00:00" }, "invalid_logged_at"],
    ["a logged_at more than a day ahead", { logged_at: "2026-08-25T10:00:00-07:00" }, "logged_at_in_future"],
    ["a scheduled_at more than a day ahead", { scheduled_at: "2026-08-25T10:00:00-07:00" }, "scheduled_at_in_future"],
    ["a malformed id", { id: "not-a-uuid" }, "invalid_id"],
    ["a malformed local_date", { local_date: "19/08/2026" }, "invalid_local_date"],
  ];

  for (const [label, patch, error] of badSets) {
    it(`rejects ${label}`, async () => {
      const set = { ...aSet(), ...patch };
      const response = await post("/api/sets", newDevice(), { sets: [set] });
      expect(response.status).toBe(200);
      const body = await response.json<{ accepted: number; rejected: Array<{ id: unknown; error: string }> }>();
      expect(body.accepted).toBe(0);
      expect(body.rejected).toEqual([{ id: set.id, error }]);
    });
  }

  it("takes the good rows and reports the bad ones", async () => {
    const device = newDevice();
    const good = aSet();
    const bad: Record<string, unknown> = { ...aSet(), target: 0 };
    const body = await (await post("/api/sets", device, { sets: [good, bad] })).json<{ accepted: number; rejected: Array<{ error: string }> }>();
    expect(body.accepted).toBe(1);
    expect(body.rejected).toEqual([{ id: bad.id, error: "invalid_target" }]);
  });

  it("tolerates a set logged slightly in the future", async () => {
    const body = await (
      await post("/api/sets", newDevice(), { sets: [{ ...aSet(), logged_at: "2026-08-20T10:00:00-07:00" }] })
    ).json<{ accepted: number }>();
    expect(body.accepted).toBe(1);
  });

  it("recomputes local_date from logged_at in the device zone", async () => {
    const device = newDevice();
    await put("/api/settings", device, defaultSettings);
    const set: Record<string, unknown> = { ...aSet(), logged_at: "2026-08-19T23:30:00-07:00", local_date: "2026-01-01" };
    await post("/api/sets", device, { sets: [set] });

    const row = await env.DB.prepare("SELECT local_date FROM sets WHERE device_id = ? AND id = ?")
      .bind(device, set.id)
      .first<{ local_date: string }>();
    expect(row?.local_date).toBe("2026-08-19");
  });

  const badBodies: Array<[string, unknown]> = [
    ["a missing sets key", {}],
    ["a non-array sets key", { sets: "nope" }],
    ["an empty batch", { sets: [] }],
    ["a batch over 200", { sets: Array.from({ length: 201 }, () => aSet()) }],
  ];

  for (const [label, body] of badBodies) {
    it(`400s on ${label}`, async () => {
      const response = await post("/api/sets", newDevice(), body);
      expect(response.status).toBe(400);
      expect((await response.json<{ error: string }>()).error).toBe("invalid_sets");
    });
  }

  it("400s on an unparseable body", async () => {
    const response = await call("/api/sets", newDevice(), { method: "POST", body: "nope" });
    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "invalid_json" });
  });

  it("takes a full batch of 200", async () => {
    const body = await (
      await post("/api/sets", newDevice(), { sets: Array.from({ length: 200 }, () => aSet()) })
    ).json<{ accepted: number }>();
    expect(body.accepted).toBe(200);
  });
});

describe("streaks over the API", () => {
  it("steps over weekend rest days", async () => {
    const device = newDevice();
    await put("/api/settings", device, { ...defaultSettings, active_days: WEEKDAYS });
    await post("/api/sets", device, {
      sets: ["2026-08-14", "2026-08-17", "2026-08-18", "2026-08-19"].map((date) => setOn(date)),
    });

    const stats = (await (await call("/api/me", device)).json<{ stats: Record<string, number> }>()).stats;
    expect(stats.streak_days).toBe(4);
    expect(stats.best_streak_days).toBe(4);
    expect(stats.today_done).toBe(1);
    expect(stats.total_done).toBe(4);
  });

  it("breaks the streak on a missed weekday", async () => {
    const device = newDevice();
    await put("/api/settings", device, { ...defaultSettings, active_days: WEEKDAYS });
    await post("/api/sets", device, { sets: ["2026-08-14", "2026-08-18", "2026-08-19"].map((date) => setOn(date)) });

    const stats = (await (await call("/api/me", device)).json<{ stats: Record<string, number> }>()).stats;
    expect(stats.streak_days).toBe(2);
    expect(stats.best_streak_days).toBe(2);
  });

  it("holds the streak on a day with nothing logged yet", async () => {
    const device = newDevice();
    await put("/api/settings", device, defaultSettings);
    await post("/api/sets", device, { sets: ["2026-08-17", "2026-08-18"].map((date) => setOn(date)) });

    const stats = (await (await call("/api/me", device)).json<{ stats: Record<string, number> }>()).stats;
    expect(stats.streak_days).toBe(2);
    expect(stats.today_done).toBe(0);
  });
});

describe("time zones", () => {
  it("splits the day at local midnight for a device in Auckland", async () => {
    const device = newDevice();
    await put("/api/settings", device, { ...defaultSettings, timezone: "Pacific/Auckland" });
    // 23:30 on 19 August in Auckland. UTC still reads 19 August for both sets
    // below, so a UTC-based server would count them on the same day.
    vi.setSystemTime(new Date("2026-08-19T11:30:00Z"));

    const tonight = { ...aSet(), logged_at: "2026-08-19T23:00:00+12:00", local_date: "2026-08-19" };
    const afterMidnight = { ...aSet(), logged_at: "2026-08-20T00:10:00+12:00", local_date: "2026-08-19" };
    const body = await (await post("/api/sets", device, { sets: [tonight, afterMidnight] })).json<{ stats: Record<string, number> }>();

    expect(body.stats.today_done).toBe(1);
    expect(body.stats.total_done).toBe(2);
    expect(body.stats.streak_days).toBe(1);

    const rows = await env.DB.prepare("SELECT id, local_date FROM sets WHERE device_id = ? ORDER BY local_date")
      .bind(device)
      .all<{ id: string; local_date: string }>();
    expect(rows.results.map((row) => row.local_date)).toEqual(["2026-08-19", "2026-08-20"]);

    const history = await (await call("/api/history?days=2", device)).json<{ days: Array<{ date: string; done: number }> }>();
    expect(history.days).toEqual([
      { date: "2026-08-18", done: 0, skipped: 0, reps: 0, seconds: 0 },
      { date: "2026-08-19", done: 1, skipped: 0, reps: 15, seconds: 0 },
    ]);
  });

  it("gives two devices at one instant different local days", async () => {
    const auckland = newDevice();
    const honolulu = newDevice();
    await put("/api/settings", auckland, { ...defaultSettings, timezone: "Pacific/Auckland" });
    await put("/api/settings", honolulu, { ...defaultSettings, timezone: "Pacific/Honolulu" });

    const logged_at = "2026-08-19T18:00:00Z";
    await post("/api/sets", auckland, { sets: [{ ...aSet(), logged_at, scheduled_at: null }] });
    await post("/api/sets", honolulu, { sets: [{ ...aSet(), logged_at, scheduled_at: null }] });

    const aucklandRow = await env.DB.prepare("SELECT local_date FROM sets WHERE device_id = ?").bind(auckland).first<{ local_date: string }>();
    const honoluluRow = await env.DB.prepare("SELECT local_date FROM sets WHERE device_id = ?").bind(honolulu).first<{ local_date: string }>();
    expect(aucklandRow?.local_date).toBe("2026-08-20");
    expect(honoluluRow?.local_date).toBe("2026-08-19");
  });
});

describe("GET /api/history", () => {
  it("defaults to 30 days ending today, zeros filled", async () => {
    const device = newDevice();
    await put("/api/settings", device, defaultSettings);
    await post("/api/sets", device, {
      sets: [
        setOn("2026-08-19"),
        setOn("2026-08-19", { exercise_id: "forearm_plank", unit: "seconds", target: 45 }),
        setOn("2026-08-17", { status: "skipped", skip_reason: "bad_time" }),
      ],
    });

    const response = await call("/api/history", device);
    expect(response.status).toBe(200);
    const body = await response.json<{ days: Array<{ date: string; done: number; skipped: number; reps: number; seconds: number }>; stats: Record<string, number> }>();

    expect(body.days).toHaveLength(30);
    expect(body.days[0]?.date).toBe("2026-07-21");
    expect(body.days.at(-1)).toEqual({ date: "2026-08-19", done: 2, skipped: 0, reps: 15, seconds: 45 });
    expect(body.days.find((entry) => entry.date === "2026-08-17")).toEqual({
      date: "2026-08-17",
      done: 0,
      skipped: 1,
      reps: 0,
      seconds: 0,
    });
    expect(body.stats.total_done).toBe(2);
  });

  it("honors ?days", async () => {
    const device = newDevice();
    const body = await (await call("/api/history?days=7", device)).json<{ days: unknown[] }>();
    expect(body.days).toHaveLength(7);
  });

  it("takes the full 365 day range", async () => {
    const body = await (await call("/api/history?days=365", newDevice())).json<{ days: unknown[] }>();
    expect(body.days).toHaveLength(365);
  });

  for (const days of ["0", "366", "-1", "abc", "7.5", ""]) {
    it(`400s on days=${days || "(empty)"}`, async () => {
      const response = await call(`/api/history?days=${days}`, newDevice());
      expect(response.status).toBe(400);
      expect((await response.json<{ error: string }>()).error).toBe("invalid_days");
    });
  }
});

describe("DELETE /api/me", () => {
  it("removes the device and cascades to settings and sets", async () => {
    const device = newDevice();
    await put("/api/settings", device, defaultSettings);
    await post("/api/sets", device, { sets: [aSet(), aSet()] });

    const response = await call("/api/me", device, { method: "DELETE" });
    expect(response.status).toBe(204);
    expect(await response.text()).toBe("");

    for (const table of ["devices", "settings", "sets"]) {
      const column = table === "devices" ? "id" : "device_id";
      const row = await env.DB.prepare(`SELECT COUNT(*) AS n FROM ${table} WHERE ${column} = ?`).bind(device).first<{ n: number }>();
      expect(row?.n, table).toBe(0);
    }
  });

  it("leaves the catalog alone", async () => {
    const device = newDevice();
    await call("/api/me", device);
    await call("/api/me", device, { method: "DELETE" });
    const row = await env.DB.prepare("SELECT COUNT(*) AS n FROM exercises").first<{ n: number }>();
    expect(row?.n).toBe(30);
  });

  it("is idempotent", async () => {
    const device = newDevice();
    await call("/api/me", device);
    expect((await call("/api/me", device, { method: "DELETE" })).status).toBe(204);
    expect((await call("/api/me", device, { method: "DELETE" })).status).toBe(204);
  });

  it("hands back a clean slate afterwards", async () => {
    const device = newDevice();
    await put("/api/settings", device, { ...defaultSettings, difficulty: "hard" });
    await call("/api/me", device, { method: "DELETE" });
    const body = await (await call("/api/me", device)).json<{ settings: Record<string, unknown> }>();
    expect(body.settings.difficulty).toBe("medium");
    expect(body.settings.timezone).toBe("UTC");
  });
});
