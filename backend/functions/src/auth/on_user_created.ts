import { FieldValue } from "firebase-admin/firestore";
import * as functionsV1 from "firebase-functions/v1";

import {
  DEFAULT_PREFERENCES_ID,
  db,
  paths,
  PREMIUM_ENTITLEMENT_ID,
} from "../lib/firestore";
import { log } from "../lib/logger";

/**
 * Bootstraps the Firestore profile when a Firebase Auth account is created
 * (spec §15). Providers linked later share the same UID, so this runs once
 * per identity. Roles are NOT assigned here — every new account is a plain
 * parent with no custom claims.
 */
// v1 trigger (auth onCreate has no v2 equivalent yet) — v2 global options
// don't apply here, so the region is pinned explicitly.
export const onUserCreated = functionsV1
  .region("southamerica-east1")
  .auth.user()
  .onCreate(async (user) => {
  const batch = db().batch();

  batch.set(db().doc(paths.user(user.uid)), {
    email: user.email ?? null,
    displayName: user.displayName ?? null,
    locale: "pt-BR",
    timezone: "America/Sao_Paulo",
    onboardingState: "created",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  batch.set(
    db()
      .collection(paths.notificationPreferences(user.uid))
      .doc(DEFAULT_PREFERENCES_ID),
    {
      dailyReminder: true,
      achievement: true,
      weeklyReport: true,
      subscription: true,
      marketing: false,
      preferredTime: "18:00",
      updatedAt: FieldValue.serverTimestamp(),
    },
  );

  // Explicit inactive entitlement: premium checks read a concrete document
  // and fail safely instead of interpreting "missing" (spec §20).
  batch.set(
    db().collection(paths.entitlements(user.uid)).doc(PREMIUM_ENTITLEMENT_ID),
    {
      active: false,
      source: "none",
      plan: null,
      features: [],
      validFrom: null,
      validUntil: null,
      updatedAt: FieldValue.serverTimestamp(),
    },
  );

  await batch.commit();
  log("auth", "user_bootstrapped", { uid: user.uid });
});
