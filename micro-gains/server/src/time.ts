// Calendar-date helpers. Everything the server calls "a day" is a YYYY-MM-DD
// string in the device's IANA zone, computed with Intl so DST and offset
// changes are the platform's problem and not ours.

const formatters = new Map<string, Intl.DateTimeFormat>();

function formatterFor(timeZone: string): Intl.DateTimeFormat {
  let formatter = formatters.get(timeZone);
  if (!formatter) {
    formatter = new Intl.DateTimeFormat("en-US", {
      timeZone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    });
    formatters.set(timeZone, formatter);
  }
  return formatter;
}

export function isValidTimeZone(timeZone: unknown): timeZone is string {
  if (typeof timeZone !== "string" || timeZone.length === 0 || timeZone.length > 64) return false;
  try {
    new Intl.DateTimeFormat("en-US", { timeZone });
    return true;
  } catch {
    return false;
  }
}

/** The device-local calendar date of an instant, as YYYY-MM-DD. */
export function localDate(instant: Date, timeZone: string): string {
  const parts = formatterFor(timeZone).formatToParts(instant);
  let year = "";
  let month = "";
  let day = "";
  for (const part of parts) {
    if (part.type === "year") year = part.value.padStart(4, "0");
    else if (part.type === "month") month = part.value;
    else if (part.type === "day") day = part.value;
  }
  return `${year}-${month}-${day}`;
}

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;
// ISO 8601 instant that carries a zone. The client always has one, and without
// it we could not place the set on a calendar day.
const ISO_INSTANT = /^\d{4}-\d{2}-\d{2}[Tt ]\d{2}:\d{2}(:\d{2})?(\.\d{1,9})?([Zz]|[+-]\d{2}:?\d{2})$/;

export function parseInstant(value: unknown): Date | null {
  if (typeof value !== "string" || !ISO_INSTANT.test(value)) return null;
  const instant = new Date(value.replace(" ", "T"));
  return Number.isFinite(instant.getTime()) ? instant : null;
}

export function isDateString(value: unknown): value is string {
  return typeof value === "string" && ISO_DATE.test(value) && !Number.isNaN(Date.parse(`${value}T00:00:00Z`));
}

const DAY_MS = 86_400_000;

function dateToMs(date: string): number {
  return Date.parse(`${date}T00:00:00Z`);
}

function msToDate(ms: number): string {
  return new Date(ms).toISOString().slice(0, 10);
}

export function addDays(date: string, delta: number): string {
  return msToDate(dateToMs(date) + delta * DAY_MS);
}

export function daysBetween(from: string, to: string): number {
  return Math.round((dateToMs(to) - dateToMs(from)) / DAY_MS);
}

/** Bit index in active_days: 0 = Monday ... 6 = Sunday. */
export function weekdayBit(date: string): number {
  return (new Date(dateToMs(date)).getUTCDay() + 6) % 7;
}

export function isActiveDay(date: string, activeDays: number): boolean {
  return (activeDays & (1 << weekdayBit(date))) !== 0;
}
