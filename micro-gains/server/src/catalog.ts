import type { Exercise, Pattern, Unit } from "./types";

interface ExerciseRow {
  id: string;
  name: string;
  pattern: string;
  unit: string;
  easy: number;
  medium: number;
  hard: number;
  cue: string;
  office_ok: number;
  needs_floor: number;
  intense: number;
}

const SELECT_EXERCISES = `SELECT id, name, pattern, unit, easy, medium, hard, cue,
  office_ok, needs_floor, intense
  FROM exercises ORDER BY sort_order, id`;

function toExercise(row: ExerciseRow): Exercise {
  return {
    id: row.id,
    name: row.name,
    pattern: row.pattern as Pattern,
    unit: row.unit as Unit,
    easy: row.easy,
    medium: row.medium,
    hard: row.hard,
    cue: row.cue,
    office_ok: row.office_ok === 1,
    needs_floor: row.needs_floor === 1,
    intense: row.intense === 1,
  };
}

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * The version is the sha256 of the served JSON, so any catalog edit changes it
 * and any two Workers on the same data agree on it. Recomputed per request: 30
 * rows hash in microseconds and a cache would go stale between a migration and
 * the deploy that follows it.
 */
export async function loadCatalog(db: D1Database): Promise<{ exercises: Exercise[]; version: string }> {
  const { results } = await db.prepare(SELECT_EXERCISES).all<ExerciseRow>();
  const exercises = results.map(toExercise);
  return { exercises, version: await sha256Hex(JSON.stringify(exercises)) };
}

export async function exerciseIds(db: D1Database): Promise<Set<string>> {
  const { results } = await db.prepare("SELECT id FROM exercises").all<{ id: string }>();
  return new Set(results.map((row) => row.id));
}

/** Accepts the version bare or quoted, weak or strong, in a comma-separated list. */
export function etagMatches(ifNoneMatch: string | null, version: string): boolean {
  if (!ifNoneMatch) return false;
  return ifNoneMatch
    .split(",")
    .map((candidate) => candidate.trim().replace(/^W\//, "").replace(/^"|"$/g, ""))
    .some((candidate) => candidate === "*" || candidate === version);
}
