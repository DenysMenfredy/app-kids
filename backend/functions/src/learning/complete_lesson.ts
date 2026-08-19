import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { trackServerEvent } from "../analytics/track_server_event";
import { db, paths } from "../lib/firestore";
import { requireAuth, requireString } from "../lib/guards";
import { log } from "../lib/logger";

/**
 * Marks a lesson completed with validated, server-timestamped data
 * (spec §15, §16). Safe to retry: completing the same lesson twice for the
 * same child on the same document id is an idempotent merge.
 */
export const completeLesson = onCall(
  { enforceAppCheck: true },
  async (request) => {
    const uid = requireAuth(request);
    const lessonId = requireString(request.data?.lessonId, "lessonId", {
      maxLength: 64,
    });
    const childId = requireString(request.data?.childId, "childId", {
      maxLength: 64,
    });

    const child = await db()
      .collection(paths.children(uid))
      .doc(childId)
      .get();
    if (!child.exists) {
      throw new HttpsError("not-found", "Perfil da criança não encontrado.");
    }

    const stats = validateStats(request.data);

    await db()
      .collection(paths.learningProgress(uid))
      .doc(`${childId}_${lessonId}`)
      .set(
        {
          lessonId,
          childId,
          status: "completed",
          completedAt: FieldValue.serverTimestamp(),
          durationSeconds: stats.durationSeconds,
          score: stats.score,
          attempts: stats.attempts,
          correctAnswers: stats.correctAnswers,
          wrongAnswers: stats.wrongAnswers,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

    trackServerEvent("lesson_completed", uid, {
      lessonId,
      childId,
      score: stats.score,
      durationSeconds: stats.durationSeconds,
    });
    log("learning", "lesson_completed", { uid, childId, lessonId });
    return { ok: true };
  },
);

interface LessonStats {
  durationSeconds: number;
  score: number;
  attempts: number;
  correctAnswers: number;
  wrongAnswers: number;
}

function validateStats(data: unknown): LessonStats {
  const d = (data ?? {}) as Record<string, unknown>;
  const int = (value: unknown, field: string, max: number): number => {
    const n = typeof value === "number" ? Math.trunc(value) : NaN;
    if (Number.isNaN(n) || n < 0 || n > max) {
      throw new HttpsError("invalid-argument", `Campo inválido: ${field}`);
    }
    return n;
  };
  return {
    durationSeconds: int(d.durationSeconds ?? 0, "durationSeconds", 24 * 3600),
    score: int(d.score ?? 0, "score", 100),
    attempts: int(d.attempts ?? 0, "attempts", 10_000),
    correctAnswers: int(d.correctAnswers ?? 0, "correctAnswers", 10_000),
    wrongAnswers: int(d.wrongAnswers ?? 0, "wrongAnswers", 10_000),
  };
}
