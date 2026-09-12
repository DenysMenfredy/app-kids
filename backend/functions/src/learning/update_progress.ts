import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { db, paths } from "../lib/firestore";
import { enforceAppCheck, requireAuth, requireString } from "../lib/guards";
import { log } from "../lib/logger";

/**
 * Records an in-progress lesson state and individual activity attempts
 * (spec §4, §15). Attempts are immutable facts; progress documents are
 * keyed by child+lesson so retries merge instead of duplicating (§20).
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

    const progressRef = db()
      .collection(paths.learningProgress(uid))
      .doc(`${childId}_${lessonId}`);

    await progressRef.set(
      {
        lessonId,
        childId,
        status,
        startedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const attempt = request.data?.attempt as
      | Record<string, unknown>
      | undefined;
    if (attempt) {
      await recordAttempt(uid, childId, lessonId, attempt);
    }

    log("learning", "progress_updated", { uid, childId, lessonId, status });
    return { ok: true };
  },
);

async function recordAttempt(
  uid: string,
  childId: string,
  lessonId: string,
  attempt: Record<string, unknown>,
): Promise<void> {
  const activityId = requireString(attempt.activityId, "attempt.activityId", {
    maxLength: 64,
  });
  if (typeof attempt.correct !== "boolean") {
    throw new HttpsError("invalid-argument", "Campo inválido: attempt.correct");
  }

  await db()
    .collection(paths.activityAttempts(uid))
    .add({
      activityId,
      lessonId,
      childId,
      type: typeof attempt.type === "string" ? attempt.type : null,
      answer: typeof attempt.answer === "string" ? attempt.answer : null,
      correct: attempt.correct,
      attemptNumber:
        typeof attempt.attemptNumber === "number"
          ? Math.max(1, Math.trunc(attempt.attemptNumber))
          : 1,
      responseTimeMs:
        typeof attempt.responseTimeMs === "number"
          ? Math.max(0, Math.trunc(attempt.responseTimeMs))
          : null,
      createdAt: FieldValue.serverTimestamp(),
    });
}
