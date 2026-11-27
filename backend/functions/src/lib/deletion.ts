import { HttpsError } from "firebase-functions/v2/https";

import { deletionBlocksOperations } from "../domain/account_deletion";
import { db, paths } from "./firestore";

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
