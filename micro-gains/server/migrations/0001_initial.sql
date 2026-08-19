-- Micro Gains initial schema. One device is one user; there are no accounts.

CREATE TABLE devices (
  id TEXT PRIMARY KEY,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  timezone TEXT NOT NULL DEFAULT 'UTC'
);

CREATE TABLE settings (
  device_id TEXT PRIMARY KEY REFERENCES devices(id) ON DELETE CASCADE,
  interval_minutes INTEGER NOT NULL DEFAULT 120
    CHECK (interval_minutes IN (60, 90, 120, 180, 240)),
  difficulty TEXT NOT NULL DEFAULT 'medium'
    CHECK (difficulty IN ('easy', 'medium', 'hard')),
  active_start_minute INTEGER NOT NULL DEFAULT 540
    CHECK (active_start_minute BETWEEN 0 AND 1439),
  active_end_minute INTEGER NOT NULL DEFAULT 1140
    CHECK (active_end_minute BETWEEN 1 AND 1440),
  -- 7-bit mask, bit0 = Monday. Zero is rejected: the streak rule needs at least
  -- one active day to anchor to, and pausing is what `enabled` is for.
  active_days INTEGER NOT NULL DEFAULT 127
    CHECK (active_days BETWEEN 1 AND 127),
  office_mode INTEGER NOT NULL DEFAULT 0 CHECK (office_mode IN (0, 1)),
  floor_ok INTEGER NOT NULL DEFAULT 1 CHECK (floor_ok IN (0, 1)),
  enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0, 1)),
  paused_until TEXT,
  exercise_levels TEXT NOT NULL DEFAULT '{}',
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  -- The window has to hold at least one slot after the first.
  CHECK (active_end_minute > active_start_minute + interval_minutes)
);

CREATE TABLE exercises (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  pattern TEXT NOT NULL
    CHECK (pattern IN ('push', 'squat', 'hinge', 'core', 'cardio', 'mobility')),
  unit TEXT NOT NULL CHECK (unit IN ('reps', 'seconds')),
  easy INTEGER NOT NULL CHECK (easy BETWEEN 1 AND 1000),
  medium INTEGER NOT NULL CHECK (medium BETWEEN 1 AND 1000),
  hard INTEGER NOT NULL CHECK (hard BETWEEN 1 AND 1000),
  cue TEXT NOT NULL,
  office_ok INTEGER NOT NULL CHECK (office_ok IN (0, 1)),
  needs_floor INTEGER NOT NULL CHECK (needs_floor IN (0, 1)),
  intense INTEGER NOT NULL DEFAULT 0 CHECK (intense IN (0, 1)),
  sort_order INTEGER NOT NULL
);

-- No FK on exercise_id: unit and target are snapshots so history survives a
-- catalog edit that drops an exercise. Existence is checked on write instead.
CREATE TABLE sets (
  device_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  id TEXT NOT NULL,
  exercise_id TEXT NOT NULL,
  target INTEGER NOT NULL CHECK (target BETWEEN 1 AND 1000),
  unit TEXT NOT NULL CHECK (unit IN ('reps', 'seconds')),
  status TEXT NOT NULL CHECK (status IN ('done', 'skipped')),
  skip_reason TEXT
    CHECK (skip_reason IS NULL OR skip_reason IN ('bad_time', 'too_hard', 'not_here')),
  scheduled_at TEXT,
  logged_at TEXT NOT NULL,
  local_date TEXT NOT NULL CHECK (local_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
  source TEXT NOT NULL CHECK (source IN ('notification', 'app')),
  CHECK (status = 'skipped' OR skip_reason IS NULL),
  PRIMARY KEY (device_id, id)
);

CREATE INDEX sets_device_local_date ON sets (device_id, local_date);
