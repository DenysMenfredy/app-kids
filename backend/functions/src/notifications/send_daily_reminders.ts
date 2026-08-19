import { onSchedule } from "firebase-functions/v2/scheduler";

import { isWithinReminderWindow } from "../domain/reminders";
import { DEFAULT_PREFERENCES_ID, db, paths } from "../lib/firestore";
import { log } from "../lib/logger";
import { sendNotificationToUser } from "./send_notification";

/**
 * Hourly sweep implementing the daily-reminder decision (spec §11):
 * unfinished lesson? → notifications enabled? → inside local-time window?
 * → FCM. The dedupe key is date-scoped, so retried runs never double-send.
 */
export const sendDailyReminders = onSchedule(
  { schedule: "every 60 minutes", timeZone: "UTC" },
  async () => {
    const now = new Date();
    const prefsSnapshot = await db()
      .collectionGroup("notificationPreferences")
      .where("dailyReminder", "==", true)
      .get();

    let sent = 0;
    for (const prefsDoc of prefsSnapshot.docs) {
      if (prefsDoc.id !== DEFAULT_PREFERENCES_ID) continue;
      const uid = prefsDoc.ref.parent.parent?.id;
      if (!uid) continue;

      const userSnap = await db().doc(paths.user(uid)).get();
      const timezone =
        (userSnap.get("timezone") as string | undefined) ??
        "America/Sao_Paulo";

      const inWindow = isWithinReminderWindow(
        {
          dailyReminder: true,
          preferredTime: prefsDoc.get("preferredTime") ?? "18:00",
        },
        timezone,
        now,
      );
      if (!inWindow) continue;

      if (await hasCompletedLessonToday(uid, timezone, now)) continue;

      const localDate = new Intl.DateTimeFormat("en-CA", {
        timeZone: timezone,
      }).format(now);
      const delivered = await sendNotificationToUser(
        uid,
        {
          type: "daily_reminder",
          title: "Letrando",
          body: "\u{1F31F} Hora da nossa aventura de hoje!",
        },
        `daily_reminder_${localDate}`,
      );
      if (delivered) sent += 1;
    }

    log("notifications", "daily_reminder_sweep_done", {
      candidates: prefsSnapshot.size,
      sent,
    });
  },
);

/** True when any lesson was completed today in the user's local calendar. */
async function hasCompletedLessonToday(
  uid: string,
  timezone: string,
  now: Date,
): Promise<boolean> {
  const localDate = new Intl.DateTimeFormat("en-CA", {
    timeZone: timezone,
  }).format(now); // YYYY-MM-DD
  const startOfDayUtc = new Date(`${localDate}T00:00:00Z`);
  // Widest possible UTC range covering the local day (±14h zone offsets).
  const rangeStart = new Date(startOfDayUtc.getTime() - 14 * 3600_000);

  const snapshot = await db()
    .collection(paths.learningProgress(uid))
    .where("status", "==", "completed")
    .where("completedAt", ">=", rangeStart)
    .get();

  return snapshot.docs.some((doc) => {
    const completedAt = doc.get("completedAt")?.toDate?.() as Date | undefined;
    if (!completedAt) return false;
    const completedLocalDate = new Intl.DateTimeFormat("en-CA", {
      timeZone: timezone,
    }).format(completedAt);
    return completedLocalDate === localDate;
  });
}
