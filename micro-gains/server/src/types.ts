export type Difficulty = "easy" | "medium" | "hard";
export type Pattern = "push" | "squat" | "hinge" | "core" | "cardio" | "mobility";
export type Unit = "reps" | "seconds";
export type SetStatus = "done" | "skipped";
export type SkipReason = "bad_time" | "too_hard" | "not_here";
export type SetSource = "notification" | "app";

export interface Exercise {
  id: string;
  name: string;
  pattern: Pattern;
  unit: Unit;
  easy: number;
  medium: number;
  hard: number;
  cue: string;
  office_ok: boolean;
  needs_floor: boolean;
  intense: boolean;
}

/** The settings a client sends. The server owns `updated_at`. */
export interface SettingsInput {
  interval_minutes: number;
  difficulty: Difficulty;
  active_start_minute: number;
  active_end_minute: number;
  active_days: number;
  office_mode: boolean;
  floor_ok: boolean;
  enabled: boolean;
  paused_until: string | null;
  exercise_levels: Record<string, Difficulty>;
  timezone: string;
}

export interface Settings extends SettingsInput {
  updated_at: string;
}

export interface SetLog {
  id: string;
  exercise_id: string;
  target: number;
  unit: Unit;
  status: SetStatus;
  skip_reason: SkipReason | null;
  scheduled_at: string | null;
  logged_at: string;
  local_date: string;
  source: SetSource;
}

export interface Stats {
  today_done: number;
  today_skipped: number;
  streak_days: number;
  best_streak_days: number;
  total_done: number;
  total_reps: number;
  total_seconds: number;
}

export interface DayTotals {
  date: string;
  done: number;
  skipped: number;
  reps: number;
  seconds: number;
}
