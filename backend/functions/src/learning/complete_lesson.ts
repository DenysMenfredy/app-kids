import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { trackServerEvent } from "../analytics/track_server_event";
import {
  applyLessonReward,
  GamificationState,
  initialGamification,
} from "../domain/gamification";
import { localDateIso } from "../domain/time";
import { db, paths } from "../lib/firestore";
import { enforceAppCheck, requireAuth, requireString } from "../lib/guards";
import { log } from "../lib/logger";

/**
 * Marks a lesson completed and grants its rewards (spec §15, §16).
 *
 * XP, coins and the daily streak are server-owned: the client reports what
 * happened in the lesson, the backend decides what it is worth (ADR 0003).
 * The reward is applied inside a transaction that first checks whether this
 * lesson was already completed, so retries and replays never mint extra XP
 * (spec §20: progress updates must be safe to retry).
 */
export const completeLesson = onCall(
  { enforceAppCheck },
  async (request) => {
    const uid = requireAuth(request);
    const lessonId = requireString(request.data?.lessonId, "lessonId", {
      maxLength: 64,
    });
    const childId = requireString(request.data?.childId, "childId", {
      maxLength: 64,
    });

    const [child, user] = await Promise.all([
      db().collection(paths.children(uid)).doc(childId).get(),
      db().doc(paths.user(uid)).get(),
    ]);
    if (!child.exists) {
      throw new HttpsError("not-found", "Perfil da criança não encontrado.");
    }

    const stats = validateStats(request.data);
    const timezone =
      (user.get("timezone") as string | undefined) ?? "America/Sao_Paulo";
    let today: string;
    try {
      today = localDateIso(new Date(), timezone);
    } catch {
      today = localDateIso(new Date(), "America/Sao_Paulo");
    }

    const progressRef = db()
      .collection(paths.learningProgress(uid))
      .doc(`${childId}_${lessonId}`);
    const gamificationRef = db()
      .collection(paths.gamification(uid))
      .doc(childId);

    const result = await db().runTransaction(async (tx) => {
      const [progressSnap, gamificationSnap] = await Promise.all([
        tx.get(progressRef),
        tx.get(gamificationRef),
      ]);

      const current: GamificationState = gamificationSnap.exists
        ? {
            xp: gamificationSnap.get("xp") ?? 0,
            coins: gamificationSnap.get("coins") ?? 0,
            streak: gamificationSnap.get("streak") ?? 0,
            lastCompletionDate:
              gamificationSnap.get("lastCompletionDate") ?? null,
          }
        : initialGamification;

      // Only a first-time completion earns rewards; re-submitting the same
      // lesson refreshes the stats but leaves the wallet untouched.
      const alreadyCompleted = progressSnap.get("status") === "completed";

      tx.set(
        progressRef,
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

      if (alreadyCompleted) {
        return { awarded: false, xpEarned: 0, coinsEarned: 0, ...current };
      }

      const next = applyLessonReward(current, today);
      tx.set(
        gamificationRef,
        {
          childId,
          xp: next.xp,
          coins: next.coins,
          streak: next.streak,
          lastCompletionDate: next.lastCompletionDate,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return {
        awarded: true,
        xpEarned: next.xp - current.xp,
        coinsEarned: next.coins - current.coins,
        ...next,
      };
    });

    if (result.awarded) {
      trackServerEvent("lesson_completed", uid, {
        lessonId,
        childId,
        score: stats.score,
        durationSeconds: stats.durationSeconds,
        streak: result.streak,
      });
    }
    log("learning", "lesson_completed", {
      uid,
      childId,
      lessonId,
      awarded: result.awarded,
      streak: result.streak,
    });

    // Totals are the source of truth for the UI; the deltas let the reward
    // screen show what this lesson actually granted.
    return {
      ok: true,
      awarded: result.awarded,
      xpEarned: result.xpEarned,
      coinsEarned: result.coinsEarned,
      xp: result.xp,
      coins: result.coins,
      streak: result.streak,
    };
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
