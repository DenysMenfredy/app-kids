import { FieldValue, Firestore } from "firebase-admin/firestore";

import { paths } from "./firestore";

/**
 * Webhook idempotency ledger (spec §8: repeated provider events must not
 * cause duplicate side effects).
 *
 * Claims `webhookEvents/{provider_eventId}` inside a transaction before any
 * side effect runs. Returns false when the event was already processed —
 * the caller must then skip all side effects and ACK the webhook.
 */
export async function claimWebhookEvent(
  firestore: Firestore,
  provider: string,
  eventId: string,
  eventType: string,
): Promise<boolean> {
  const ref = firestore
    .collection(paths.webhookEvents)
    .doc(`${provider}_${eventId}`);

  return firestore.runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    if (existing.exists && existing.get("processed") === true) {
      return false;
    }
    tx.set(ref, {
      provider,
      eventType,
      processed: true,
      processedAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
}
