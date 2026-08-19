import { describe, expect, it } from "vitest";
import { computeStats, fillDays } from "../src/stats";
import { addDays, isActiveDay, localDate, parseInstant, weekdayBit } from "../src/time";
import type { DayTotals } from "../src/types";

// 2026-08-19 is a Wednesday. Every fixture below hangs off that.
const WEEKDAYS = 0b0011111; // Mon..Fri
const EVERY_DAY = 127;

function day(date: string, done: number, skipped = 0, reps = 0, seconds = 0): DayTotals {
  return { date, done, skipped, reps, seconds };
}

describe("time", () => {
  it("names the weekday bit with Monday at zero", () => {
    expect(weekdayBit("2026-08-17")).toBe(0);
    expect(weekdayBit("2026-08-19")).toBe(2);
    expect(weekdayBit("2026-08-23")).toBe(6);
  });

  it("reads active_days as a Monday-first mask", () => {
    expect(isActiveDay("2026-08-19", WEEKDAYS)).toBe(true);
    expect(isActiveDay("2026-08-15", WEEKDAYS)).toBe(false);
    expect(isActiveDay("2026-08-15", EVERY_DAY)).toBe(true);
  });

  it("puts an instant on the device's calendar day, not UTC's", () => {
    const instant = new Date("2026-08-19T12:10:00Z");
    expect(localDate(instant, "Pacific/Auckland")).toBe("2026-08-20");
    expect(localDate(instant, "UTC")).toBe("2026-08-19");
    expect(localDate(instant, "America/Los_Angeles")).toBe("2026-08-19");
  });

  it("survives a DST spring forward in the device zone", () => {
    // 2026-03-08 02:00 never happens in Los Angeles.
    expect(localDate(new Date("2026-03-08T09:30:00Z"), "America/Los_Angeles")).toBe("2026-03-08");
    expect(localDate(new Date("2026-03-08T06:30:00Z"), "America/Los_Angeles")).toBe("2026-03-07");
  });

  it("rejects timestamps without an offset", () => {
    expect(parseInstant("2026-08-19T10:00:00Z")).toBeInstanceOf(Date);
    expect(parseInstant("2026-08-19T10:00:00-07:00")).toBeInstanceOf(Date);
    expect(parseInstant("2026-08-19T10:00:00")).toBeNull();
    expect(parseInstant("2026-08-19")).toBeNull();
    expect(parseInstant("not a time")).toBeNull();
  });

  it("adds days across a month boundary", () => {
    expect(addDays("2026-08-31", 1)).toBe("2026-09-01");
    expect(addDays("2026-01-01", -1)).toBe("2025-12-31");
  });
});

describe("computeStats", () => {
  it("is all zeros with no history", () => {
    expect(computeStats([], EVERY_DAY, "2026-08-19")).toEqual({
      today_done: 0,
      today_skipped: 0,
      streak_days: 0,
      best_streak_days: 0,
      total_done: 0,
      total_reps: 0,
      total_seconds: 0,
    });
  });

  it("totals today and all time separately", () => {
    const days = [day("2026-08-18", 3, 1, 45, 0), day("2026-08-19", 2, 2, 20, 60)];
    const stats = computeStats(days, EVERY_DAY, "2026-08-19");
    expect(stats.today_done).toBe(2);
    expect(stats.today_skipped).toBe(2);
    expect(stats.total_done).toBe(5);
    expect(stats.total_reps).toBe(65);
    expect(stats.total_seconds).toBe(60);
  });

  it("counts consecutive days ending today", () => {
    const days = [day("2026-08-17", 1), day("2026-08-18", 1), day("2026-08-19", 1)];
    expect(computeStats(days, EVERY_DAY, "2026-08-19").streak_days).toBe(3);
  });

  it("keeps the streak alive on a day with nothing logged yet", () => {
    const days = [day("2026-08-17", 1), day("2026-08-18", 1)];
    expect(computeStats(days, EVERY_DAY, "2026-08-19").streak_days).toBe(2);
  });

  it("breaks on a missed active day", () => {
    const days = [day("2026-08-16", 1), day("2026-08-18", 1)];
    const stats = computeStats(days, EVERY_DAY, "2026-08-19");
    expect(stats.streak_days).toBe(1);
    expect(stats.best_streak_days).toBe(1);
  });

  it("steps over rest days without breaking or extending", () => {
    // Fri, Mon, Tue, Wed with a weekday-only mask: the weekend is invisible.
    const days = [day("2026-08-14", 1), day("2026-08-17", 1), day("2026-08-18", 1), day("2026-08-19", 1)];
    expect(computeStats(days, WEEKDAYS, "2026-08-19").streak_days).toBe(4);
    // The same history on an every-day mask has two missed days in it.
    expect(computeStats(days, EVERY_DAY, "2026-08-19").streak_days).toBe(3);
  });

  it("does not let a rest-day set extend the streak", () => {
    const days = [day("2026-08-15", 1), day("2026-08-18", 1), day("2026-08-19", 1)];
    // Sat 15 is a rest day, so it neither counts nor bridges the gap to Fri 14.
    expect(computeStats(days, WEEKDAYS, "2026-08-19").streak_days).toBe(2);
  });

  it("anchors to the most recent active day when today is a rest day", () => {
    const days = [day("2026-08-13", 1), day("2026-08-14", 1)];
    // Today is Sunday, the mask is weekdays, so the run through Friday stands.
    expect(computeStats(days, WEEKDAYS, "2026-08-16").streak_days).toBe(2);
  });

  it("remembers the best run even after it breaks", () => {
    const days = [
      day("2026-08-10", 1),
      day("2026-08-11", 1),
      day("2026-08-12", 1),
      day("2026-08-13", 1),
      day("2026-08-19", 1),
    ];
    const stats = computeStats(days, EVERY_DAY, "2026-08-19");
    expect(stats.streak_days).toBe(1);
    expect(stats.best_streak_days).toBe(4);
  });

  it("ignores days that logged only skips", () => {
    const days = [day("2026-08-18", 0, 3), day("2026-08-19", 1)];
    expect(computeStats(days, EVERY_DAY, "2026-08-19").streak_days).toBe(1);
  });
});

describe("fillDays", () => {
  it("fills gaps with zeros and keeps the range inclusive", () => {
    const filled = fillDays([day("2026-08-18", 2, 0, 30)], "2026-08-17", "2026-08-19");
    expect(filled.map((entry) => entry.date)).toEqual(["2026-08-17", "2026-08-18", "2026-08-19"]);
    expect(filled[0]).toEqual(day("2026-08-17", 0));
    expect(filled[1]?.reps).toBe(30);
  });

  it("drops days outside the range", () => {
    const filled = fillDays([day("2026-07-01", 5)], "2026-08-19", "2026-08-19");
    expect(filled).toHaveLength(1);
    expect(filled[0]?.done).toBe(0);
  });
});
