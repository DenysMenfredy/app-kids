import { randomUUID } from "node:crypto";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { db, paths } from "../lib/firestore";
import { tokenHash } from "./device_registration";

export interface NotificationPayload {
  type: "daily_reminder" | "achievement" | "weekly_report" | "subscription";
  title: string;
  body: string;
  data?: Record<string, string>;
}

const category = {
  daily_reminder: "dailyReminder", achievement: "achievement",
  weekly_report: "weeklyReport", subscription: "subscription",
} as const;

/** FCM acceptance is NOT delivery. Retries are at-least-once across process crashes. */
export async function sendNotificationToUser(
  uid: string, payload: NotificationPayload, dedupeKey: string,
): Promise<boolean> {
  const notificationRef = db().doc(`${paths.notifications(uid)}/${dedupeKey}`);
  const claimId = randomUUID();
  const claimed = await db().runTransaction(async (tx) => {
    const existing = await tx.get(notificationRef);
    if (existing.get("status") === "accepted" || existing.get("sentAt") ||
        (existing.get("leaseUntil")?.toMillis() ?? 0) > Date.now()) return false;
    tx.set(notificationRef, {
      type: payload.type, title: payload.title, body: payload.body,
      status: "sending", claimId,
      leaseUntil: Timestamp.fromMillis(Date.now() + 120_000),
      attemptedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return true;
  });
  if (!claimed) return false;

  const finish = async (values: Record<string, unknown>) => {
    await db().runTransaction(async (tx) => {
      if ((await tx.get(notificationRef)).get("claimId") === claimId) {
        tx.update(notificationRef, { ...values, leaseUntil: null });
      }
    });
  };
  let anyAccepted = false;
  try {
    const saved = await notificationRef.get();
    const settled = new Set<string>(saved.get("settledTokenHashes") ?? []);
    const devices = await db().collection(paths.devices(uid))
      .where("notificationsEnabled", "==", true).get();
    const byToken = new Map<string, typeof devices.docs[number]>();
    for (const device of devices.docs) {
      const token = device.get("fcmToken");
      if (typeof token === "string" && token && !settled.has(tokenHash(token))) byToken.set(token, device);
    }
    const entries = [...byToken.entries()];
    let retry = entries.length === 0;
    for (let offset = 0; offset < entries.length; offset += 500) {
      // Recheck preferences and ownership immediately before each external batch.
      const [parent, prefs, lease] = await db().getAll(
        db().doc(paths.user(uid)), db().doc(`${paths.notificationPreferences(uid)}/default`), notificationRef,
      );
      if (lease.get("claimId") !== claimId) return false;
      if (!parent.exists || prefs.get(category[payload.type]) !== true) {
        await finish({ status: "suppressed" });
        return false;
      }
      const candidates: typeof entries = [];
      for (const entry of entries.slice(offset, offset + 500)) {
        const [current, owner] = await db().getAll(entry[1].ref,
          db().doc(`notificationTokens/${tokenHash(entry[0])}`));
        if (current.get("notificationsEnabled") === true && current.get("fcmToken") === entry[0] &&
            owner.get("uid") === uid && owner.get("deviceId") === entry[1].id) candidates.push(entry);
      }
      if (!candidates.length) { retry = true; continue; }
      const messageId = tokenHash(`${uid}/${dedupeKey}`);
      const response = await getMessaging().sendEachForMulticast({
        tokens: candidates.map(([token]) => token),
        notification: { title: payload.title, body: payload.body },
        data: { ...payload.data, type: payload.type, notificationId: messageId },
        android: { notification: { channelId: "lele_parent_updates", tag: messageId } },
        apns: { headers: { "apns-collapse-id": messageId }, payload: { aps: { sound: "default" } } },
      });
      for (let index = 0; index < candidates.length; index++) {
        const [token, device] = candidates[index];
        const result = response.responses[index];
        const invalid = ["messaging/registration-token-not-registered", "messaging/invalid-registration-token"]
          .includes(result.error?.code ?? "");
        if (result.success || invalid) {
          settled.add(tokenHash(token));
          if (result.success) anyAccepted = true;
          if (invalid) await db().runTransaction(async (tx) => {
            if ((await tx.get(device.ref)).get("fcmToken") === token) tx.delete(device.ref);
          });
        } else retry = true;
      }
      await db().runTransaction(async (tx) => {
        if ((await tx.get(notificationRef)).get("claimId") === claimId) {
          tx.update(notificationRef, { settledTokenHashes: [...settled] });
        }
      });
    }
    await finish({ status: retry ? "retry" : "accepted",
      ...(anyAccepted ? { acceptedAt: FieldValue.serverTimestamp() } : {}) });
    return anyAccepted;
  } catch (error) {
    await finish({ status: "retry" });
    throw error;
  }
}
