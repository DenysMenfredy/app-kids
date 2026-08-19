import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

import { deriveEntitlement } from "../domain/entitlement";
import { Subscription } from "../domain/subscription";
import { db, paths, PREMIUM_ENTITLEMENT_ID } from "../lib/firestore";
import { log } from "../lib/logger";

/**
 * Recomputes the user's entitlement whenever any of their subscription
 * documents changes (spec §7: subscription ≠ entitlement; §16: entitlement
 * changes are backend-only). Single writer for entitlement state.
 */
export const syncEntitlement = onDocumentWritten(
  "users/{uid}/subscriptions/{subscriptionId}",
  async (event) => {
    const uid = event.params.uid;
    await syncEntitlementForUser(uid);
  },
);

/** Derives the entitlement from the user's best current subscription. */
export async function syncEntitlementForUser(uid: string): Promise<void> {
  const snapshot = await db().collection(paths.subscriptions(uid)).get();
  const now = new Date();

  const subscriptions = snapshot.docs.map((doc) => toDomain(doc.data()));

  // Best = the granting subscription with the latest period end.
  const best = subscriptions
    .map((sub) => ({ sub, ent: deriveEntitlement(sub, now) }))
    .filter(({ ent }) => ent.active)
    .sort(
      (a, b) =>
        (b.ent.validUntil?.getTime() ?? 0) - (a.ent.validUntil?.getTime() ?? 0),
    )[0];

  const entitlement = best?.ent ?? deriveEntitlement(null, now);

  await db()
    .collection(paths.entitlements(uid))
    .doc(PREMIUM_ENTITLEMENT_ID)
    .set({
      active: entitlement.active,
      source: entitlement.source,
      plan: entitlement.plan,
      features: entitlement.features,
      validFrom: entitlement.validFrom
        ? Timestamp.fromDate(entitlement.validFrom)
        : null,
      validUntil: entitlement.validUntil
        ? Timestamp.fromDate(entitlement.validUntil)
        : null,
      updatedAt: FieldValue.serverTimestamp(),
    });

  log("subscriptions", "entitlement_synced", {
    uid,
    active: entitlement.active,
    plan: entitlement.plan,
  });
}

function toDomain(data: FirebaseFirestore.DocumentData): Subscription {
  return {
    provider: data.provider,
    providerCustomerId: data.providerCustomerId,
    providerSubscriptionId: data.providerSubscriptionId,
    planId: data.planId,
    status: data.status,
    currency: data.currency,
    amountCents: data.amountCents,
    interval: data.interval,
    currentPeriodStart: (data.currentPeriodStart as Timestamp).toDate(),
    currentPeriodEnd: (data.currentPeriodEnd as Timestamp).toDate(),
    cancelAtPeriodEnd: data.cancelAtPeriodEnd,
  };
}
