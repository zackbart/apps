import { addDays, daysBetween, isActiveDay } from "./time";
import type { DayTotals, Stats } from "./types";

// A streak walks backwards over active days only. A rest day is invisible: it
// neither breaks the run nor counts toward it. One week of stepping is always
// enough to find the next active day because the mask has at least one bit set.
function previousActiveDay(date: string, activeDays: number): string {
  let candidate = date;
  for (let step = 0; step < 7; step += 1) {
    candidate = addDays(candidate, -1);
    if (isActiveDay(candidate, activeDays)) return candidate;
  }
  return candidate;
}

function activeDayBetween(earlier: string, later: string, activeDays: number): boolean {
  const gap = daysBetween(earlier, later);
  // Any gap wider than a week contains every weekday, so it contains an active one.
  if (gap > 7) return true;
  for (let step = 1; step < gap; step += 1) {
    if (isActiveDay(addDays(earlier, step), activeDays)) return true;
  }
  return false;
}

function currentStreak(doneDays: Set<string>, activeDays: number, today: string): number {
  // The streak ends today when today is active and already logged, otherwise at
  // the most recent active day. An untouched active today does not zero it out.
  let day = isActiveDay(today, activeDays) && doneDays.has(today) ? today : previousActiveDay(today, activeDays);
  let streak = 0;
  while (isActiveDay(day, activeDays) && doneDays.has(day)) {
    streak += 1;
    day = previousActiveDay(day, activeDays);
  }
  return streak;
}

function bestStreak(doneDates: string[], activeDays: number): number {
  let best = 0;
  let run = 0;
  let previous: string | null = null;
  for (const date of doneDates) {
    if (!isActiveDay(date, activeDays)) continue;
    if (previous !== null && activeDayBetween(previous, date, activeDays)) run = 0;
    run += 1;
    if (run > best) best = run;
    previous = date;
  }
  return best;
}

/**
 * `days` is every day the device has logged, ascending. `today` is the device's
 * local date. Both streaks are scored against the device's current active_days
 * mask, so changing the mask re-scores history.
 */
export function computeStats(days: DayTotals[], activeDays: number, today: string): Stats {
  let totalDone = 0;
  let totalReps = 0;
  let totalSeconds = 0;
  let todayDone = 0;
  let todaySkipped = 0;
  const doneDates: string[] = [];

  for (const day of days) {
    totalDone += day.done;
    totalReps += day.reps;
    totalSeconds += day.seconds;
    if (day.done > 0) doneDates.push(day.date);
    if (day.date === today) {
      todayDone = day.done;
      todaySkipped = day.skipped;
    }
  }

  const doneDays = new Set(doneDates);
  return {
    today_done: todayDone,
    today_skipped: todaySkipped,
    streak_days: currentStreak(doneDays, activeDays, today),
    best_streak_days: bestStreak(doneDates, activeDays),
    total_done: totalDone,
    total_reps: totalReps,
    total_seconds: totalSeconds,
  };
}

/** One entry per calendar day in [from, to], zeros filled, ascending. */
export function fillDays(days: DayTotals[], from: string, to: string): DayTotals[] {
  const byDate = new Map(days.map((day) => [day.date, day]));
  const filled: DayTotals[] = [];
  const span = daysBetween(from, to);
  for (let step = 0; step <= span; step += 1) {
    const date = addDays(from, step);
    filled.push(byDate.get(date) ?? { date, done: 0, skipped: 0, reps: 0, seconds: 0 });
  }
  return filled;
}
