import { getAuth } from "firebase-admin/auth";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  DELETION_FLOW_VERSION,
  deletionRequestDecision,
  parseAccountDeletionRequest,
  reauthRefusal,
} from "../domain/account_deletion";
import { db, paths } from "../lib/firestore";
import { enforceAppCheck, requireAuth } from "../lib/guards";
import { log, logError } from "../lib/logger";

/**
 * Requests account deletion after a recent reauthentication.
 *
 * The callable records a server-owned tombstone, then revokes refresh tokens.
 * It is idempotent: a pending/completed request is returned unchanged, while a
 * `failed` request can be retried. The durable data/Auth deletion worker is
 * PR08b; this callable deletes no user data.
 */
export const requestAccountDeletion = onCall(
  { enforceAppCheck },
  async (request) => {
    const uid = requireAuth(request);
    const input = parseAccountDeletionRequest(request.data);
    if (!input) {
      throw new HttpsError("invalid-argument", "Solicitação de exclusão inválida.");
    }

    const authTime = request.auth?.token?.auth_time;
    const authTimeSeconds = typeof authTime === "number" ? authTime : null;
    const reauth = reauthRefusal(authTimeSeconds, Math.floor(Date.now() / 1000));
    if (reauth || authTimeSeconds === null) {
      throw new HttpsError(
        "failed-precondition",
        "Reautentique-se antes de solicitar a exclusão da conta.",
        reauth ?? { code: "reauth_required", maxAgeSeconds: 0 },
      );
    }

    const firestore = db();
    const deletionRef = firestore.doc(paths.accountDeletion(uid));
    const outcome = await firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(deletionRef);
      const decision = deletionRequestDecision(
        snapshot.exists ? (snapshot.data() ?? null) : null,
        uid,
      );
      if (decision.kind === "invalid") {
        throw new HttpsError(
          "failed-precondition",
          "Estado de exclusão inválido; fale com o suporte.",
          { code: "deletion_state_invalid" },
        );
      }
      if (decision.kind === "existing") {
        return {
          changed: false,
          status: decision.status,
          requestId: decision.requestId,
          sessionsRevoked: snapshot.get("sessionsRevokedAt") != null,
        };
      }

      const now = FieldValue.serverTimestamp();
      transaction.set(deletionRef, {
        schemaVersion: 1,
        flowVersion: DELETION_FLOW_VERSION,
        status: "requested",
        requestId: input.requestId,
        uid,
        // Corroborated by the signed Auth token, not a server clock.
        reauthenticatedAt: Timestamp.fromMillis(authTimeSeconds * 1000),
        requestedAt: now,
        updatedAt: now,
        // The sweep reads this as a due job; a retry after `failed` resets it.
        attempts: 0,
        nextAttemptAt: now,
      });
      return {
        changed: true,
        status: "requested" as const,
        requestId: input.requestId,
        sessionsRevoked: false,
      };
    });

    if (!outcome.sessionsRevoked) {
      try {
        await getAuth().revokeRefreshTokens(uid);
        await deletionRef.update({
          sessionsRevokedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        outcome.sessionsRevoked = true;
      } catch (error) {
        logError("deletion", "session_revocation_failed", {
          requestId: outcome.requestId,
        });
        throw new HttpsError(
          "internal",
          "Solicitação registrada, mas não foi possível encerrar as sessões; tente novamente.",
          { code: "session_revocation_failed" },
        );
      }
    }

    log("deletion", "account_deletion_requested", {
      requestId: outcome.requestId,
      status: outcome.status,
      changed: outcome.changed,
    });
    return {
      ok: true,
      changed: outcome.changed,
      status: outcome.status,
      requestId: outcome.requestId,
      flowVersion: DELETION_FLOW_VERSION,
    };
  },
);
