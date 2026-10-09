import { localDateIso } from "./time";

export const MAX_ACTIVE_MILLISECONDS = 30 * 60_000;
export const PRESENCE_WINDOW_MILLISECONDS = 30_000;

/** Server-received presence is a bounded activity signal, not proof of attention. */
export function creditActiveTime(
  current: Record<string, number>, lastActiveAt: number, now: number,
  timezone: string, active: boolean,
): Record<string, number> {
  const next = { ...current };
  const used = Object.values(next).reduce((sum, value) => sum + value, 0);
  const duration = active ? Math.max(0, Math.min(
    now - lastActiveAt, PRESENCE_WINDOW_MILLISECONDS,
    MAX_ACTIVE_MILLISECONDS - used,
  )) : 0;
  const end = lastActiveAt + duration;
  let cursor = lastActiveAt;
  while (cursor < end) {
    const day = localDateIso(new Date(cursor), timezone);
    let boundary = end;
    if (localDateIso(new Date(end - 1), timezone) !== day) {
      let low = cursor + 1;
      let high = end;
      while (low < high) {
        const middle = Math.floor((low + high) / 2);
        if (localDateIso(new Date(middle), timezone) === day) low = middle + 1;
        else high = middle;
      }
      boundary = low;
    }
    next[day] = (next[day] ?? 0) + boundary - cursor;
    cursor = boundary;
  }
  return next;
}

export function nextLocalMidnight(now: Date, timezone: string): number {
  const today = localDateIso(now, timezone);
  let low = now.getTime() + 1;
  let high = low + 27 * 3600_000;
  while (low < high) {
    const middle = Math.floor((low + high) / 2);
    if (localDateIso(new Date(middle), timezone) === today) low = middle + 1;
    else high = middle;
  }
  return low;
}

export function learningWeekDates(now: Date, timezone: string): string[] {
  const today = localDateIso(now, timezone);
  const day = new Date(`${today}T00:00:00Z`);
  day.setUTCDate(day.getUTCDate() - (day.getUTCDay() + 6) % 7);
  return Array.from({ length: 7 }, (_, index) => {
    const date = new Date(day);
    date.setUTCDate(day.getUTCDate() + index);
    return date.toISOString().slice(0, 10);
  });
}

export function validTimezone(raw: unknown): string {
  if (typeof raw === "string") {
    try { localDateIso(new Date(), raw); return raw; } catch { /* legacy fallback */ }
  }
  return "America/Sao_Paulo";
}
