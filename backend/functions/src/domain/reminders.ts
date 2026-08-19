/**
 * Daily reminder window logic (spec §11). Pure and timezone-aware so it can
 * be unit-tested without any Firebase dependency.
 */

/** How wide the send window is. The scheduler runs hourly, so a 60-minute
 *  window guarantees exactly one qualifying run per day per user. */
export const REMINDER_WINDOW_MINUTES = 60;

export interface ReminderPreferences {
  dailyReminder: boolean;
  preferredTime: string; // "HH:mm" in the user's local time
}

/** Returns the user's local wall-clock minutes-of-day for the given instant. */
export function localMinutesOfDay(now: Date, timezone: string): number {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  });
  const parts = formatter.formatToParts(now);
  const hour = Number(parts.find((p) => p.type === "hour")?.value ?? 0);
  const minute = Number(parts.find((p) => p.type === "minute")?.value ?? 0);
  return hour * 60 + minute;
}

export function parsePreferredTime(preferredTime: string): number | null {
  const match = /^([01]?\d|2[0-3]):([0-5]\d)$/.exec(preferredTime);
  if (!match) return null;
  return Number(match[1]) * 60 + Number(match[2]);
}

/**
 * A reminder may fire only when:
 *  1. daily reminders are enabled, and
 *  2. the user's local time is inside [preferredTime, preferredTime + window).
 *
 * The unfinished-lesson check happens separately against Firestore.
 */
export function isWithinReminderWindow(
  prefs: ReminderPreferences,
  timezone: string,
  now: Date,
): boolean {
  if (!prefs.dailyReminder) return false;
  const preferred = parsePreferredTime(prefs.preferredTime);
  if (preferred === null) return false;

  let local: number;
  try {
    local = localMinutesOfDay(now, timezone);
  } catch {
    return false; // unknown timezone — fail safe, send nothing
  }

  // Window may wrap past midnight (e.g. preferred 23:30).
  const delta = (local - preferred + 24 * 60) % (24 * 60);
  return delta < REMINDER_WINDOW_MINUTES;
}
