import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { mayUpdateLessonProgress } from "../domain/progress_transition";
import { db, paths } from "../lib/firestore";
import { enforceAppCheck, requireAuth, requireString } from "../lib/guards";
import { log } from "../lib/logger";

/**
 * Records an in-progress lesson state (spec §4, §15). Progress documents
 * are keyed by child+lesson so retries merge instead of duplicating (§20).
 * Activity attempts stay unavailable until the backend can verify answers
 * against the published activity content.
 */
export const updateProgress = onCall(
  { enforceAppCheck },
  async (request) => {
    const uid = requireAuth(request);
    const lessonId = requireString(request.data?.lessonId, "lessonId", {
      maxLength: 64,
    });
    const childId = requireString(request.data?.childId, "childId", {
      maxLength: 64,
    });
    const status = requireString(request.data?.status, "status", {
      maxLength: 16,
    });
    if (!["in_progress", "abandoned"].includes(status)) {
      // "completed" must go through completeLesson.
      throw new HttpsError("invalid-argument", "Status inválido.");
    }
    if (request.data?.attempt != null) {
      // Client-reported correctness is not evidence. This is intentionally
      // unavailable until the server-scored activity contract is implemented.
      throw new HttpsError(
        "failed-precondition",
        "Registro de atividade indisponível.",
      );
    }

    const lessonRef = db().collection(paths.lessons).doc(lessonId);
    const childRef = db().collection(paths.children(uid)).doc(childId);
    const progressRef = db()
      .collection(paths.learningProgress(uid))
      .doc(`${childId}_${lessonId}`);

    await db().runTransaction(async (tx) => {
      const [child, lesson, progress] = await Promise.all([
        tx.get(childRef),
        tx.get(lessonRef),
        tx.get(progressRef),
      ]);
      const lessonData = lesson.data();
      if (!child.exists) {
        throw new HttpsError("not-found", "Perfil da criança não encontrado.");
      }
      if (!lessonData || lessonData.published !== true) {
        throw new HttpsError("not-found", "Lição indisponível.");
      }
      if (!mayUpdateLessonProgress({
        childExists: child.exists,
        lessonId,
        lessonCourseId:
          typeof lessonData.courseId === "string" ? lessonData.courseId : null,
        lessonPublished: lessonData.published === true,
        currentCourseId:
          typeof child.get("currentCourseId") === "string"
            ? child.get("currentCourseId") as string
            : null,
        currentLessonId:
          typeof child.get("currentLessonId") === "string"
            ? child.get("currentLessonId") as string
            : null,
        existingStatus:
          typeof progress.get("status") === "string"
            ? progress.get("status") as string
            : null,
      })) {
        throw new HttpsError(
          "failed-precondition",
          "Lição fora do percurso da criança ou já concluída.",
        );
      }

      const update: Record<string, unknown> = {
        lessonId,
        childId,
        status,
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (!progress.exists) update.startedAt = FieldValue.serverTimestamp();
      tx.set(progressRef, update, { merge: true });
    });

    log("learning", "progress_updated", { uid, childId, lessonId, status });
    return { ok: true };
  },
);
