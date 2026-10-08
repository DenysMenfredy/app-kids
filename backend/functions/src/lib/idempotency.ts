import { FieldValue, Firestore, Timestamp } from "firebase-admin/firestore";
import { randomUUID } from "node:crypto";

import { paths } from "./firestore";

/**
 * Webhook idempotency ledger (spec §8: repeated provider events must not
 * cause duplicate side effects).
 *
 * Claims an event with a short lease. It is only marked processed after all
 * side effects finish, so a crashed invocation can be retried after the lease.
 */
export async function claimWebhookEvent(
  firestore: Firestore,
  provider: string,
  eventId: string,
  eventType: string,
): Promise<
  | { status: "claimed"; claimToken: string }
  | { status: "processed" }
  | { status: "in_progress" }
> {
  const ref = firestore
    .collection(paths.webhookEvents)
    .doc(`${provider}_${eventId}`);
  const claimToken = randomUUID();
  const now = Date.now();

  return firestore.runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    if (
      existing.exists &&
      (existing.get("state") === "processed" ||
        existing.get("processed") === true)
    ) {
      return { status: "processed" };
    }
    const lease = existing.get("leaseExpiresAt") as Timestamp | undefined;
    if (
      existing.get("state") === "processing" &&
      lease &&
      lease.toMillis() > now
    ) {
      return { status: "in_progress" };
    }
    tx.set(ref, {
      provider,
      eventType,
      state: "processing",
      processed: false,
      claimToken,
      attempts: Number(existing.get("attempts") ?? 0) + 1,
      leaseExpiresAt: Timestamp.fromMillis(now + 5 * 60 * 1000),
      updatedAt: FieldValue.serverTimestamp(),
      ...(existing.exists ? {} : { receivedAt: FieldValue.serverTimestamp() }),
    });
    return { status: "claimed", claimToken };
  });
}

/** Marks completion only for the invocation that still owns the lease. */
export async function completeWebhookEvent(
  firestore: Firestore,
  provider: string,
  eventId: string,
  claimToken: string,
): Promise<boolean> {
  const ref = firestore
    .collection(paths.webhookEvents)
    .doc(`${provider}_${eventId}`);
  return firestore.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    if (snapshot.get("claimToken") !== claimToken) return false;
    tx.update(ref, {
      state: "processed",
      processed: true,
      processedAt: FieldValue.serverTimestamp(),
      leaseExpiresAt: FieldValue.delete(),
      claimToken: FieldValue.delete(),
    });
    return true;
  });
}

/** Makes failed events retryable without allowing an old worker to clear a new claim. */
export async function releaseWebhookEvent(
  firestore: Firestore,
  provider: string,
  eventId: string,
  claimToken: string,
): Promise<void> {
  const ref = firestore
    .collection(paths.webhookEvents)
    .doc(`${provider}_${eventId}`);
  await firestore.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    if (snapshot.get("claimToken") !== claimToken) return;
    tx.update(ref, {
      state: "pending",
      processed: false,
      leaseExpiresAt: FieldValue.delete(),
      claimToken: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}
