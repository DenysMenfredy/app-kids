import { getAuth } from "firebase-admin/auth";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { isRole } from "../domain/roles";
import { db } from "../lib/firestore";
import { enforceAppCheck, requireRole, requireString } from "../lib/guards";
import { log } from "../lib/logger";

/**
 * Assigns a role via Firebase custom claims (spec §14). Admin-only, and
 * every change lands in an audit log (spec §19: auditable administrative
 * access). The client can never self-assign: this is the single write path.
 */
export const setUserRole = onCall(
  { enforceAppCheck },
  async (request) => {
    const adminUid = requireRole(request, "admin");
    const targetUid = requireString(request.data?.uid, "uid", {
      maxLength: 128,
    });
    const role = requireString(request.data?.role, "role", { maxLength: 32 });
    if (!isRole(role)) {
      throw new HttpsError("invalid-argument", "Papel desconhecido.");
    }
    if (targetUid === adminUid) {
      throw new HttpsError(
        "failed-precondition",
        "Administradores não podem alterar o próprio papel.",
      );
    }

    await getAuth().setCustomUserClaims(targetUid, { role });

    await db().collection("adminAuditLogs").add({
      action: "set_user_role",
      actorUid: adminUid,
      targetUid,
      role,
      at: FieldValue.serverTimestamp(),
    });

    log("admin", "role_assigned", { adminUid, targetUid, role });
    return { ok: true };
  },
);
