import { Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import { deletionBlocksOperations } from "../domain/account_deletion";
import { db, paths } from "./firestore";

/**
 * Read-only check used by payment webhooks and other late writers. A
 * tombstone in any state except retryable `failed` keeps the account closed.
 */
export async function isAccountDeletionBlocked(
  firestore: Firestore,
  uid: string,
): Promise<boolean> {
  const snapshot = await firestore.doc(paths.accountDeletion(uid)).get();
  if (!snapshot.exists) return false;
  return deletionBlocksOperations(snapshot.get("status"));
}

/**
 * Stops new data collection while an account-deletion request is pending.
 * The tombstone is server-owned; a malformed or unknown status fails closed.
 */
export async function requireNoPendingDeletion(uid: string): Promise<void> {
  const snapshot = await db().doc(paths.accountDeletion(uid)).get();
  if (!snapshot.exists) return;

  const status = snapshot.get("status");
  if (!deletionBlocksOperations(status)) return;

  throw new HttpsError(
    "failed-precondition",
    "A conta está em processo de exclusão; novas operações estão bloqueadas.",
    {
      code: "account_deletion_pending",
      status: typeof status === "string" ? status : "unknown",
    },
  );
}
