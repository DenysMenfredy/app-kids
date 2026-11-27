import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  parseParentConsentInput,
  purposesEqual,
} from "../domain/consent";
import { requireNoPendingDeletion } from "../lib/deletion";
import { db, paths } from "../lib/firestore";
import { enforceAppCheck, requireAuth } from "../lib/guards";
import { log } from "../lib/logger";

/**
 * Records the parent's acceptance of the current child-data terms.
 *
 * Version, purposes and origin are validated against server-side allowlists;
 * the UID comes from the authenticated Auth token and both timestamps are
 * server values. The document is a singleton (`consent/current`), so retries
 * are idempotent: an identical submission returns `changed: false` without a
 * second write, while a new text version resets `acceptedAt`.
 */
export const recordParentConsent = onCall(
  { enforceAppCheck },
  async (request) => {
    const uid = requireAuth(request);
    await requireNoPendingDeletion(uid);
    const input = parseParentConsentInput(request.data);
    if (!input) {
      throw new HttpsError(
        "invalid-argument",
        "Consentimento inválido: versão, finalidades ou origem não reconhecidas.",
      );
    }

    const firestore = db();
    const consentRef = firestore.doc(paths.parentConsent(uid));
    const changed = await firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(consentRef);
      const prior = snapshot.exists ? snapshot.data() : undefined;
      const sameVersion = prior?.textVersion === input.textVersion;
      const unchanged = prior !== undefined &&
        sameVersion &&
        prior.schemaVersion === 1 &&
        prior.uid === uid &&
        prior.origin === input.origin &&
        prior.acceptedAt != null &&
        purposesEqual(prior.purposes, input.purposes);
      if (unchanged) return false;

      const now = FieldValue.serverTimestamp();
      transaction.set(consentRef, {
        schemaVersion: 1,
        textVersion: input.textVersion,
        purposes: input.purposes,
        origin: input.origin,
        uid,
        // A new text version is a new acceptance; changing only optional
        // purposes keeps the original acceptance time.
        acceptedAt: sameVersion ? prior?.acceptedAt ?? now : now,
        updatedAt: now,
      });
      return true;
    });

    log("consent", "parent_consent_recorded", {
      uid,
      textVersion: input.textVersion,
      changed,
    });
    return {
      ok: true,
      changed,
      textVersion: input.textVersion,
      purposes: input.purposes,
      origin: input.origin,
    };
  },
);
