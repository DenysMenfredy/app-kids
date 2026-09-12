import { FieldValue } from "firebase-admin/firestore";
import { onCall } from "firebase-functions/v2/https";

import { db, paths } from "../lib/firestore";
import { enforceAppCheck, requireAuth, requireString } from "../lib/guards";
import { log } from "../lib/logger";

/**
 * Registers/refreshes a device for push notifications (spec §10). Runs as a
 * callable (not a direct Firestore write) so token bookkeeping stays
 * consistent and validated in one place.
 */
export const registerDevice = onCall(
  { enforceAppCheck },
  async (request) => {
    const uid = requireAuth(request);
    const deviceId = requireString(request.data?.deviceId, "deviceId", {
      maxLength: 128,
    });
    const fcmToken = requireString(request.data?.fcmToken, "fcmToken", {
      maxLength: 512,
    });
    const platform = requireString(request.data?.platform, "platform", {
      maxLength: 16,
    });

    await db()
      .collection(paths.devices(uid))
      .doc(deviceId)
      .set(
        {
          platform,
          fcmToken,
          appVersion: request.data?.appVersion ?? null,
          deviceModel: request.data?.deviceModel ?? null,
          osVersion: request.data?.osVersion ?? null,
          notificationsEnabled: request.data?.notificationsEnabled !== false,
          lastSeenAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

    log("notifications", "device_registered", { uid, deviceId, platform });
    return { ok: true };
  },
);
