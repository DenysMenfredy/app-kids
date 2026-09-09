import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { db } from "../lib/firestore";
import { requireRole, requireString } from "../lib/guards";
import { log } from "../lib/logger";

/**
 * Content management (spec §5, §13). Content is configuration-driven:
 * courses/modules/lessons/activities are Firestore documents, and this is
 * their only write path — restricted to content_editor/admin roles.
 */
const CONTENT_COLLECTIONS = new Set([
  "courses",
  "modules",
  "lessons",
  "activities",
  "assessments",
]);

type Action = "upsert" | "publish" | "unpublish";

export const manageContent = onCall(
  { enforceAppCheck: true },
  async (request) => {
    const editorUid = requireRole(request, "content_editor", "admin");
    const collection = requireString(request.data?.collection, "collection", {
      maxLength: 32,
    });
    const docId = requireString(request.data?.docId, "docId", {
      maxLength: 128,
    });
    const action = requireString(request.data?.action, "action", {
      maxLength: 16,
    }) as Action;

    if (!CONTENT_COLLECTIONS.has(collection)) {
      throw new HttpsError("invalid-argument", "Coleção de conteúdo inválida.");
    }

    const ref = db().collection(collection).doc(docId);

    switch (action) {
      case "upsert": {
        const content = request.data?.content;
        if (typeof content !== "object" || content === null) {
          throw new HttpsError("invalid-argument", "Conteúdo ausente.");
        }
        // New content is never auto-published; publishing is explicit.
        await ref.set(
          {
            ...(content as Record<string, unknown>),
            published: false,
            updatedAt: FieldValue.serverTimestamp(),
            updatedBy: editorUid,
          },
          { merge: true },
        );
        break;
      }
      case "publish":
      case "unpublish": {
        const snap = await ref.get();
        if (!snap.exists) {
          throw new HttpsError("not-found", "Documento não encontrado.");
        }
        await ref.set(
          {
            published: action === "publish",
            updatedAt: FieldValue.serverTimestamp(),
            updatedBy: editorUid,
          },
          { merge: true },
        );
        break;
      }
      default:
        throw new HttpsError("invalid-argument", "Ação inválida.");
    }

    await db().collection("adminAuditLogs").add({
      action: `content_${action}`,
      actorUid: editorUid,
      collection,
      docId,
      at: FieldValue.serverTimestamp(),
    });

    log("admin", "content_managed", {
      editorUid,
      collection,
      docId,
      action,
    });
    return { ok: true };
  },
);
