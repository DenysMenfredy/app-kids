import { DocumentData, Timestamp } from "firebase-admin/firestore";
import { creditActiveTime, validTimezone } from "../domain/active_time";

export function sessionClockPatch(session: DocumentData, now: Date) {
  const current = session.activeMillisecondsByDate ?? {};
  const activeMillisecondsByDate = session.timingVersion === 1
    ? creditActiveTime(current, session.lastActiveAt?.toMillis?.() ?? now.getTime(),
      now.getTime(), validTimezone(session.timezone), session.status === "active")
    : {};
  return { timingVersion: 1, activeMillisecondsByDate,
    lastActiveAt: Timestamp.fromDate(now) };
}
