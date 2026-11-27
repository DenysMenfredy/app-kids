import { randomUUID } from "node:crypto";

import { getAuth } from "firebase-admin/auth";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { onSchedule } from "firebase-functions/v2/scheduler";

import {
  DELETION_USER_COLLECTIONS,
  DELETION_WORKER_LEASE_MS,
  FINANCIAL_RETENTION_PLACEHOLDER,
  deletionClaimDecision,
  deletionRetryDelayMs,
} from "../domain/deletion_worker";
import { db, paths } from "../lib/firestore";
import { log, logError } from "../lib/logger";

export type DeletionProcessResult = "completed" | "failed" | "skipped" | "invalid";

function errorCode(error: unknown): string {
  if (error && typeof error === "object" && "code" in error) {
    const code = (error as { code?: unknown }).code;
    if (typeof code === "string" && code.length <= 120) return code;
  }
  return error instanceof Error ? error.name : "unknown";
}

/**
 * Deletes explicit child/user collections, the user document, user-prefixed
 * Storage objects and the Auth account. It deliberately does not touch
 * `subscriptions`, the `deletion` tombstone or the top-level Stripe mappings:
 * those are the minimal financial reconciliation placeholder pending D07.
 */
async function deleteUserData(uid: string): Promise<void> {
  const firestore = db();
  for (const collection of DELETION_USER_COLLECTIONS) {
    await firestore.recursiveDelete(
      firestore.collection(`users/${uid}/${collection}`),
    );
  }
  // Trial eligibility is not a financial record; remove it explicitly.
  await firestore.doc(paths.billingTrial(uid)).delete();

  const bucket = getStorage().bucket(process.env.STORAGE_BUCKET || undefined);
  await bucket.deleteFiles({ prefix: `users/${uid}/`, force: true });

  try {
    await getAuth().deleteUser(uid);
  } catch (error) {
    if ((error as { code?: string }).code !== "auth/user-not-found") throw error;
  }

  // The user document goes last. Its surviving subcollections are only the
  // tombstone and the financial subscription history.
  await firestore.doc(paths.user(uid)).delete();
}

async function finish(
  uid: string,
  claimToken: string,
  fields: Record<string, unknown>,
): Promise<boolean> {
  const firestore = db();
  const ref = firestore.doc(paths.accountDeletion(uid));
  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (snapshot.get("workerClaim") !== claimToken) return false;
    transaction.update(ref, fields);
    return true;
  });
}

/**
 * Processes one tombstone with a lease and claim token. Re-running after a
 * crash/partial failure is safe: deletes are idempotent and `deleteUser`
 * treats `auth/user-not-found` as success.
 */
export async function processDeletion(
  uid: string,
  nowMillis = Date.now(),
): Promise<DeletionProcessResult> {
  const firestore = db();
  const tombstoneRef = firestore.doc(paths.accountDeletion(uid));
  const claimToken = randomUUID();
  const leaseExpiresAt = Timestamp.fromMillis(
    nowMillis + DELETION_WORKER_LEASE_MS,
  );

  const claim = await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(tombstoneRef);
    const record = snapshot.exists ? (snapshot.data() ?? null) : null;
    const decision = deletionClaimDecision(record, nowMillis);
    if (decision !== "claim") return { claimed: false as const, decision };

    const attempts = Number(record?.attempts ?? 0) + 1;
    transaction.update(tombstoneRef, {
      status: "processing",
      attempts,
      workerClaim: claimToken,
      processingStartedAt: FieldValue.serverTimestamp(),
      leaseExpiresAt,
      // The lease is also the next time a crashed worker is due.
      nextAttemptAt: leaseExpiresAt,
      lastErrorCode: FieldValue.delete(),
      lastErrorAt: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { claimed: true as const, attempts };
  });

  if (!claim.claimed) {
    return claim.decision === "invalid" ? "invalid" : "skipped";
  }

  try {
    await deleteUserData(uid);
    const completed = await finish(uid, claimToken, {
      status: "completed",
      completedAt: FieldValue.serverTimestamp(),
      financialRetention: FINANCIAL_RETENTION_PLACEHOLDER,
      leaseExpiresAt: FieldValue.delete(),
      nextAttemptAt: FieldValue.delete(),
      workerClaim: FieldValue.delete(),
      lastErrorCode: FieldValue.delete(),
      lastErrorAt: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (!completed) {
      logError("deletion", "account_deletion_claim_lost", {
        attempts: claim.attempts,
      });
      return "skipped";
    }
    log("deletion", "account_deletion_completed", {
      attempts: claim.attempts,
    });
    return "completed";
  } catch (error) {
    const code = errorCode(error);
    const retryDelay = deletionRetryDelayMs(claim.attempts);
    const failed = await finish(uid, claimToken, {
      status: "failed",
      lastErrorCode: code,
      lastErrorAt: FieldValue.serverTimestamp(),
      leaseExpiresAt: FieldValue.delete(),
      nextAttemptAt: Timestamp.fromMillis(nowMillis + retryDelay),
      workerClaim: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    logError("deletion", "account_deletion_failed", {
      attempts: claim.attempts,
      errorCode: code,
      retryScheduled: failed,
    });
    return "failed";
  }
}

/** Finds due tombstones and processes them one by one; one failure is isolated. */
export async function runDeletionSweep(nowMillis = Date.now()): Promise<void> {
  const snapshot = await db()
    .collectionGroup("deletion")
    .where("status", "in", ["requested", "failed", "processing"])
    .limit(50)
    .get();

  let processed = 0;
  for (const document of snapshot.docs) {
    const uid = document.ref.parent.parent?.id;
    if (!uid) continue;
    try {
      const result = await processDeletion(uid, nowMillis);
      if (result === "completed" || result === "failed") processed += 1;
    } catch (error) {
      // One broken job must not stop the remaining candidates. Its tombstone
      // keeps the lease/backoff state, so a later sweep can reclaim it.
      logError("deletion", "account_deletion_job_crashed", {
        errorCode: error instanceof Error ? error.name : "unknown",
      });
    }
  }
  log("deletion", "account_deletion_sweep", {
    candidates: snapshot.size,
    processed,
  });
}

/**
 * Durable sweep. A crashed invocation is safe to retry: the lease and claim
 * token prevent two workers from completing the same tombstone, and failed
 * jobs carry their own exponential backoff.
 */
export const processAccountDeletions = onSchedule(
  {
    schedule: "every 15 minutes",
    timeZone: "UTC",
    region: "southamerica-east1",
    timeoutSeconds: 540,
  },
  async () => {
    await runDeletionSweep();
  },
);
