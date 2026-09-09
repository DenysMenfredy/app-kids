/**
 * Timezone helpers shared by scheduling and streak logic. Kept pure so both
 * can be unit-tested without Firebase.
 */

/** The user's local calendar date as `YYYY-MM-DD`. */
export function localDateIso(now: Date, timezone: string): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: timezone }).format(now);
}

/** True when `later` is exactly the calendar day after `earlier`. */
export function isNextCalendarDay(earlier: string, later: string): boolean {
  const previous = new Date(`${earlier}T00:00:00Z`);
  if (Number.isNaN(previous.getTime())) return false;
  previous.setUTCDate(previous.getUTCDate() + 1);
  return previous.toISOString().slice(0, 10) === later;
}
