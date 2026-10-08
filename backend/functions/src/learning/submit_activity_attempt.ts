import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { mayCompleteLesson } from "../domain/lesson_completion";
import {
  ActivityDocument,
  ActivityProgress,
  InvalidActivityResponseError,
  isActivityComplete,
  scoreActivityResponse,
} from "../domain/lesson_sessions";
import { db, paths } from "../lib/firestore";
import { enforceAppCheck, requireAuth, requireString } from "../lib/guards";
import { hasLessonAccess } from "./lesson_access";

const MAX_ATTEMPTS_PER_ACTIVITY = 100;

/** Stores a deduplicated answer and scores it against trusted content. */
export const submitActivityAttempt = onCall(
  { enforceAppCheck },
  async (request) => {
    const uid = requireAuth(request);
    const childId = requireString(request.data?.childId, "childId", {
      maxLength: 64,
    });
    const sessionId = requireString(request.data?.sessionId, "sessionId", {
      maxLength: 64,
    });
    const activityId = requireString(request.data?.activityId, "activityId", {
      maxLength: 64,
    });
    const requestId = requireString(request.data?.requestId, "requestId", {
      maxLength: 64,
    });
    if (!/^[A-Za-z0-9_-]+$/.test(requestId)) {
      throw new HttpsError("invalid-argument", "Campo inválido: requestId");
    }

    const firestore = db();
    const sessionRef = firestore.collection(paths.sessions(uid)).doc(sessionId);
    const activityRef = firestore.collection(paths.activities).doc(activityId);
    const activityAttemptId = `${sessionId}_${requestId}`;
    const attemptRef = firestore
      .collection(paths.activityAttempts(uid))
      .doc(activityAttemptId);
    const childRef = firestore.collection(paths.children(uid)).doc(childId);

    let result: { correct: boolean; activityCompleted: boolean };
    try {
      result = await firestore.runTransaction(async (tx) => {
        const [sessionSnap, activitySnap, childSnap, attemptSnap] =
          await Promise.all([
            tx.get(sessionRef),
            tx.get(activityRef),
            tx.get(childRef),
            tx.get(attemptRef),
          ]);
        if (attemptSnap.exists) {
          return {
            correct: attemptSnap.get("correct") === true,
            activityCompleted: attemptSnap.get("activityCompleted") === true,
          };
        }
        if (!sessionSnap.exists || sessionSnap.get("status") !== "active") {
          throw new HttpsError("failed-precondition", "Sessão indisponível.");
        }
        const session = sessionSnap.data()!;
        if (
          session.childId !== childId ||
          !Array.isArray(session.activityIds) ||
          !session.activityIds.includes(activityId)
        ) {
          throw new HttpsError("permission-denied", "Atividade fora da sessão.");
        }
        if (
          !activitySnap.exists ||
          activitySnap.get("published") !== true ||
          activitySnap.get("lessonId") !== session.lessonId
        ) {
          throw new HttpsError("failed-precondition", "Atividade indisponível.");
        }
        if (!childSnap.exists) {
          throw new HttpsError("not-found", "Perfil da criança não encontrado.");
        }

        const lessonSnap = await tx.get(
          firestore.collection(paths.lessons).doc(session.lessonId),
        );
        const progressRef = firestore
          .collection(paths.learningProgress(uid))
          .doc(`${childId}_${session.lessonId}`);
        const progressSnap = await tx.get(progressRef);
        const lesson = lessonSnap.data();
        if (
          !lesson ||
          !Array.isArray(lesson.activityIds) ||
          lesson.activityIds.length !== session.activityIds.length ||
          lesson.activityIds.some((id: unknown, index: number) =>
            id !== session.activityIds[index],
          )
        ) {
          throw new HttpsError("failed-precondition", "Manifesto da sessão alterado.");
        }
        if (!await hasLessonAccess(tx, uid, lesson)) {
          throw new HttpsError("permission-denied", "Esta lição exige Premium.");
        }
        if (
          !mayCompleteLesson(
            {
              id: session.lessonId,
              courseId: typeof lesson.courseId === "string" ? lesson.courseId : "",
              published: lesson.published === true,
            },
            {
              currentCourseId: childSnap.get("currentCourseId"),
              currentLessonId: childSnap.get("currentLessonId"),
            },
            progressSnap.get("status") === "completed",
          )
        ) {
          throw new HttpsError("failed-precondition", "Lição fora do percurso.");
        }

        const activity = {
          ...activitySnap.data(),
          id: activitySnap.id,
        } as ActivityDocument;
        let score: { correct: boolean; completionKey: string | null };
        try {
          score = scoreActivityResponse(activity, request.data?.response);
        } catch (error) {
          if (error instanceof InvalidActivityResponseError) {
            throw new HttpsError("invalid-argument", "Resposta inválida.");
          }
          throw error;
        }

        const allProgress = (session.activityProgress ?? {}) as Record<
          string,
          ActivityProgress
        >;
        const previous = allProgress[activityId] ?? {
          attempts: 0,
          correctAnswers: 0,
          wrongAnswers: 0,
          completed: false,
          completedItems: [],
        };
        const completedItems = new Set(previous.completedItems ?? []);
        const alreadyComplete = isActivityComplete(activity, previous);
        const alreadyCounted = score.completionKey !== null &&
          completedItems.has(score.completionKey);
        const countThisAttempt = !alreadyComplete && !alreadyCounted;

        if (countThisAttempt && previous.attempts >= MAX_ATTEMPTS_PER_ACTIVITY) {
          throw new HttpsError(
            "resource-exhausted",
            "Limite de tentativas atingido para esta atividade.",
          );
        }

        if (score.correct && score.completionKey !== null) {
          completedItems.add(score.completionKey);
        }
        const next: ActivityProgress = {
          attempts: previous.attempts + (countThisAttempt ? 1 : 0),
          correctAnswers: previous.correctAnswers +
            (countThisAttempt && score.correct ? 1 : 0),
          wrongAnswers: previous.wrongAnswers +
            (countThisAttempt && !score.correct ? 1 : 0),
          completed: alreadyComplete || score.correct ||
            (activity.type === "match" && isActivityComplete(activity, {
              ...previous,
              completedItems: [...completedItems],
            })),
          completedItems: [...completedItems],
        };
        allProgress[activityId] = next;

        const activityCompleted = isActivityComplete(activity, next);
        tx.set(sessionRef, {
          activityProgress: allProgress,
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        tx.create(attemptRef, {
          childId,
          sessionId,
          lessonId: session.lessonId,
          activityId,
          requestId,
          correct: score.correct,
          counted: countThisAttempt,
          activityCompleted,
          response: sanitizeResponse(request.data?.response),
          createdAt: FieldValue.serverTimestamp(),
        });
        return { correct: score.correct, activityCompleted };
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      throw error;
    }
    return { ok: true, ...result };
  },
);

/** Persist only the small answer/evidence fields needed for auditability. */
function sanitizeResponse(raw: unknown): Record<string, unknown> {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) return {};
  const response = raw as Record<string, unknown>;
  if (typeof response.selectedLabel === "string") {
    return { selectedLabel: response.selectedLabel.slice(0, 80) };
  }
  if (typeof response.upper === "string" && typeof response.lower === "string") {
    return { upper: response.upper.slice(0, 16), lower: response.lower.slice(0, 16) };
  }
  if (
    typeof response.strokeCount === "number" &&
    typeof response.pointCount === "number" &&
    typeof response.durationMillis === "number"
  ) {
    return {
      strokeCount: response.strokeCount,
      pointCount: response.pointCount,
      durationMillis: response.durationMillis,
    };
  }
  return {};
}
