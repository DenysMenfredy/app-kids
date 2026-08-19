import { FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

import { db, paths } from "../lib/firestore";
import { log, logError } from "../lib/logger";

export interface NotificationPayload {
  type: "daily_reminder" | "achievement" | "weekly_report" | "subscription";
  title: string;
  body: string;
  data?: Record<string, string>;
}

/**
 * Sends a push to every enabled device of a user, cleans up invalid tokens
 * (spec §24) and records the notification document. A `dedupeKey` makes
 * retries safe: the same key never produces a second user-facing message
 * (spec §20).
 */
export async function sendNotificationToUser(
  uid: string,
  payload: NotificationPayload,
  dedupeKey: string,
): Promise<boolean> {
  const notificationRef = db()
    .collection(paths.notifications(uid))
    .doc(dedupeKey);

  // Claim the dedupe key before any send happens.
  const claimed = await db().runTransaction(async (tx) => {
    const existing = await tx.get(notificationRef);
    if (existing.exists) return false;
    tx.set(notificationRef, {
      type: payload.type,
      title: payload.title,
      body: payload.body,
      sentAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
  if (!claimed) {
    log("notifications", "notification_deduped", { uid, dedupeKey });
    return false;
  }

  const devices = await db()
    .collection(paths.devices(uid))
    .where("notificationsEnabled", "==", true)
    .get();
  if (devices.empty) {
    log("notifications", "no_devices", { uid });
    return false;
  }

  const tokens = devices.docs
    .map((doc) => doc.get("fcmToken") as string)
    .filter(Boolean);

  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title: payload.title, body: payload.body },
    data: { type: payload.type, ...payload.data },
  });

  // Invalid token cleanup.
  const invalid: Promise<unknown>[] = [];
  response.responses.forEach((result, index) => {
    const code = result.error?.code;
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token"
    ) {
      invalid.push(devices.docs[index].ref.delete());
    } else if (result.error) {
      logError("notifications", "send_failed", {
        uid,
        code,
        message: result.error.message,
      });
    }
  });
  await Promise.all(invalid);

  log("notifications", "notification_sent", {
    uid,
    type: payload.type,
    successCount: response.successCount,
    failureCount: response.failureCount,
    invalidTokensRemoved: invalid.length,
  });
  return response.successCount > 0;
}
