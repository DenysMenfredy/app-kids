import { HttpsError } from "firebase-functions/v2/https";

import { consentRefusal } from "../domain/consent";
import { db, paths } from "./firestore";

/**
 * Gate for every server path that creates or collects child data.
 *
 * The consent document is server-owned (ADR 0020). A missing, malformed or
 * outdated record fails closed; a parent must record the current version
 * through `recordParentConsent` before creating a child or writing learning
 * evidence. The details payload is part of the client contract.
 */
export async function requireCurrentParentConsent(uid: string): Promise<void> {
  const snapshot = await db().doc(paths.parentConsent(uid)).get();
  const refusal = consentRefusal(
    snapshot.exists ? (snapshot.data() ?? null) : null,
    uid,
  );
  if (!refusal) return;

  throw new HttpsError(
    "failed-precondition",
    refusal.code === "consent_required"
      ? "Registre o consentimento do responsável antes de continuar."
      : "O consentimento do responsável está desatualizado. Registre a versão atual.",
    refusal,
  );
}
