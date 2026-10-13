import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { db } from "../lib/firestore";
import { enforceAppCheck, requireRole, requireString } from "../lib/guards";
import { log } from "../lib/logger";
import { bookPublicationProblem } from "../domain/books";
import { readLessonBundle } from "../learning/lesson_bundle";

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
  "books",
  "bookContents",
  "stories",
]);

type Action = "upsert" | "publish" | "unpublish";

export const manageContent = onCall(
  { enforceAppCheck },
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
        if (typeof content !== "object" || content === null || Array.isArray(content)) {
          throw new HttpsError("invalid-argument", "Conteúdo ausente.");
        }
        if (collection === "books" && "pages" in content) {
          throw new HttpsError("invalid-argument", "Páginas pertencem a bookContents.");
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
        if (["activities", "stories"].includes(collection) && action === "publish") {
          throw new HttpsError("failed-precondition", "Publique a lição para validar seu conteúdo completo.");
        }
        if (collection === "lessons") {
          if (action === "unpublish") {
            await ref.update({published:false,updatedAt:FieldValue.serverTimestamp(),updatedBy:editorUid});
            break;
          }
          await db().runTransaction(async (tx) => {
            const bundle = await readLessonBundle(tx, docId, false);
            const update = { published: action === "publish",
              updatedAt: FieldValue.serverTimestamp(), updatedBy: editorUid };
            tx.set(ref, {...update,contentVersion:Number(bundle.lesson.contentVersion)+1}, { merge: true });
            for (const activity of bundle.activities) {
              tx.set(db().collection("activities").doc(activity.id), update, { merge: true });
            }
            if (bundle.story) tx.set(db().collection("stories").doc(String(bundle.story.id)), update, { merge: true });
          });
          break;
        }
        if (collection === "bookContents" && action === "publish") {
          throw new HttpsError("failed-precondition", "Publique o livro em books para validar suas páginas.");
        }
        if (collection === "books") {
          const contentRef = db().collection("bookContents").doc(docId);
          await db().runTransaction(async (tx) => {
            const [book, content] = await Promise.all([tx.get(ref), tx.get(contentRef)]);
            if (!book.exists) throw new HttpsError("not-found", "Livro não encontrado.");
            if (action === "publish") {
              const problem = bookPublicationProblem(docId, book.data()!, content.data() ?? {});
              if (problem) throw new HttpsError("failed-precondition", problem);
            }
            const update = {
              published: action === "publish",
              updatedAt: FieldValue.serverTimestamp(), updatedBy: editorUid,
            };
            tx.set(ref, update, { merge: true });
            if (content.exists) tx.set(contentRef, update, { merge: true });
          });
          break;
        }
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
