import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { trackServerEvent } from "../analytics/track_server_event";
import {
  applyLessonReward,
  GamificationState,
  initialGamification,
} from "../domain/gamification";
import { mayCompleteLesson } from "../domain/lesson_completion";
import {
  ActivityDocument,
  ActivityProgress,
  summarizeLessonSession,
} from "../domain/lesson_sessions";
import { localDateIso } from "../domain/time";
import { db, paths } from "../lib/firestore";
import { findNextLessonId } from "./next_lesson";
import { enforceAppCheck, requireAuth, requireString } from "../lib/guards";
import { log } from "../lib/logger";
import { hasLessonAccess } from "./lesson_access";

/**
 * Marks a lesson completed and grants its rewards (spec §15, §16).
 *
 * XP, coins, score and answer counts are server-owned. Completion requires a
 * server-created session whose activity answers were scored against published
 * content. The reward transaction is idempotent per child and lesson.
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
    const sessionId = requireString(request.data?.sessionId, "sessionId", {
      maxLength: 64,
    });

    const lessonRef = db().collection(paths.lessons).doc(lessonId);
    const [lesson, user] = await Promise.all([
      lessonRef.get(),
      db().doc(paths.user(uid)).get(),
    ]);
    const lessonData = lesson.data();
    if (!lessonData || lessonData.published !== true) {
      throw new HttpsError("not-found", "Lição indisponível.");
    }
    const courseId = lessonData.courseId;
    const lessonNumber = lessonData.number;
    if (typeof courseId !== "string" || typeof lessonNumber !== "number") {
      throw new HttpsError("internal", "Lição sem percurso válido.");
    }

    const timezone =
      (user.get("timezone") as string | undefined) ?? "America/Sao_Paulo";
    let today: string;
    try {
      today = localDateIso(new Date(), timezone);
    } catch {
      today = localDateIso(new Date(), "America/Sao_Paulo");
    }

    // The next-lesson query must run before the transaction. Re-read the
    // current lesson in the transaction so an unpublish cannot race a grant.
    const nextLessonId = await findNextLessonId(
      db(), courseId, lessonNumber,
    );

    const childRef = db().collection(paths.children(uid)).doc(childId);
    const progressRef = db()
      .collection(paths.learningProgress(uid))
      .doc(`${childId}_${lessonId}`);
    const gamificationRef = db()
      .collection(paths.gamification(uid))
      .doc(childId);
    const sessionRef = db().collection(paths.sessions(uid)).doc(sessionId);

    const result = await db().runTransaction(async (tx) => {
      const sessionSnap = await tx.get(sessionRef);
      if (!sessionSnap.exists) {
        throw new HttpsError("failed-precondition", "Sessão de lição inválida.");
      }
      const session = sessionSnap.data()!;
      const activityIds = session.activityIds;
      if (
        session.childId !== childId ||
        session.lessonId !== lessonId ||
        !Array.isArray(activityIds) ||
        activityIds.length !== 4 ||
        (session.status !== "active" && session.status !== "completed")
      ) {
        throw new HttpsError("failed-precondition", "Sessão de lição inválida.");
      }
      const activityRefs = activityIds.map((activityId: unknown) => {
        if (typeof activityId !== "string" || activityId.length > 64) {
          throw new HttpsError("failed-precondition", "Sessão de lição inválida.");
        }
        return db().collection(paths.activities).doc(activityId);
      });
      const [progressSnap, gamificationSnap, childSnap, currentLesson,
        ...activitySnaps] = await Promise.all([
        tx.get(progressRef),
        tx.get(gamificationRef),
        tx.get(childRef),
        tx.get(lessonRef),
        ...activityRefs.map((ref) => tx.get(ref)),
      ]);

      if (!childSnap.exists) {
        throw new HttpsError("not-found", "Perfil da criança não encontrado.");
      }
      const currentLessonData = currentLesson.data();
      if (!currentLessonData || currentLessonData.published !== true) {
        throw new HttpsError("not-found", "Lição indisponível.");
      }
      if (
        !Array.isArray(currentLessonData.activityIds) ||
        currentLessonData.activityIds.length !== activityIds.length ||
        currentLessonData.activityIds.some((id: unknown, index: number) =>
          id !== activityIds[index],
        )
      ) {
        throw new HttpsError("failed-precondition", "Manifesto da sessão alterado.");
      }
      if (currentLessonData.courseId !== courseId ||
          currentLessonData.number !== lessonNumber) {
        throw new HttpsError("aborted", "Lição alterada; tente novamente.");
      }
      if (!await hasLessonAccess(tx, uid, currentLessonData)) {
        throw new HttpsError("permission-denied", "Esta lição exige Premium.");
      }
      if (!mayCompleteLesson(
        { id: lessonId, courseId: currentLessonData.courseId,
          published: currentLessonData.published },
        { currentCourseId: childSnap.get("currentCourseId"),
          currentLessonId: childSnap.get("currentLessonId") },
        progressSnap.get("status") === "completed",
      )) {
        throw new HttpsError(
          "failed-precondition", "Lição fora do percurso da criança.",
        );
      }

      if (activitySnaps.some((activity) =>
        !activity.exists || activity.get("published") !== true ||
        activity.get("lessonId") !== lessonId,
      )) {
        throw new HttpsError("failed-precondition", "Conteúdo da sessão indisponível.");
      }
      const activities = activitySnaps.map((activity) => ({
        ...activity.data(),
        id: activity.id,
      })) as ActivityDocument[];
      if (
        activities.map((activity) => activity.type).join(",") !==
        "tap,match,trace,listen"
      ) {
        throw new HttpsError("failed-precondition", "Tipos de atividade alterados.");
      }
      const activityProgress = (session.activityProgress ?? {}) as Record<
        string,
        ActivityProgress
      >;
      const startedAt = session.startedAt?.toDate?.();
      if (!(startedAt instanceof Date) || Number.isNaN(startedAt.getTime())) {
        throw new HttpsError("failed-precondition", "Sessão sem início válido.");
      }
      let stats;
      try {
        stats = summarizeLessonSession(
          activities,
          activityProgress,
          startedAt,
          new Date(),
        );
      } catch {
        throw new HttpsError(
          "failed-precondition",
          "Conclua as atividades antes de finalizar a lição.",
        );
      }

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

      // Move the child on, but only when they finished the lesson they were
      // actually on. Replaying an earlier lesson must not drag them
      // backwards, and finishing the last lesson leaves them where they are.
      const onThisLesson = childSnap.get("currentLessonId") === lessonId;
      const advanceTo = onThisLesson ? nextLessonId : null;
      if (advanceTo) {
        tx.set(
          childRef,
          {
            currentLessonId: advanceTo,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }

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
      tx.set(sessionRef, {
        status: "completed",
        completedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });

      if (alreadyCompleted) {
        return {
          awarded: false,
          xpEarned: 0,
          coinsEarned: 0,
          nextLessonId: advanceTo,
          score: stats.score,
          durationSeconds: stats.durationSeconds,
          ...current,
        };
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
        nextLessonId: advanceTo,
        score: stats.score,
        durationSeconds: stats.durationSeconds,
        ...next,
      };
    });

    if (result.awarded) {
      trackServerEvent("lesson_completed", uid, {
        lessonId,
        score: result.score,
        durationSeconds: result.durationSeconds,
        streak: result.streak,
      });
    }
    log("learning", "lesson_completed", {
      uid,
      childId,
      lessonId,
      awarded: result.awarded,
      streak: result.streak,
      nextLessonId: result.nextLessonId,
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
      // Null when the child replayed an older lesson, or finished the last
      // one. The app also sees this through the child profile stream.
      nextLessonId: result.nextLessonId,
    };
  },
);
