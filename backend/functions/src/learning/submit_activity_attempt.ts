import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { mayCompleteLesson } from "../domain/lesson_completion";
import {
  ActivityProgress,
  InvalidActivityResponseError,
  isActivityComplete,
  scoreActivityResponse,
} from "../domain/lesson_sessions";
import { db, paths } from "../lib/firestore";
import { enforceAppCheck, requireAuth, requireString } from "../lib/guards";
import { hasLessonAccess } from "./lesson_access";
import { sessionClockPatch } from "./session_clock";
import { readLessonBundle, requireSessionBundle } from "./lesson_bundle";
import { scoredActivities } from "../domain/lesson_content";

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
    const activityAttemptId = `${sessionId}_${requestId}`;
    const attemptRef = firestore
      .collection(paths.activityAttempts(uid))
      .doc(activityAttemptId);
    const childRef = firestore.collection(paths.children(uid)).doc(childId);

    let result: { correct: boolean; activityCompleted: boolean };
    try {
      result = await firestore.runTransaction(async (tx) => {
        const [sessionSnap, childSnap, attemptSnap] =
          await Promise.all([
            tx.get(sessionRef),
            tx.get(childRef),
            tx.get(attemptRef),
          ]);
        if (!childSnap.exists || !sessionSnap.exists || sessionSnap.get("childId") !== childId) {
          throw new HttpsError("not-found", "Sessão indisponível.");
        }
        if (attemptSnap.exists) {
          if (attemptSnap.get("activityId") !== activityId || attemptSnap.get("childId") !== childId) {
            throw new HttpsError("invalid-argument", "Request ID já utilizado.");
          }
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
        const bundle = await readLessonBundle(tx, session.lessonId);
        requireSessionBundle(session, bundle);
        const progressRef = firestore
          .collection(paths.learningProgress(uid))
          .doc(`${childId}_${session.lessonId}`);
        const progressSnap = await tx.get(progressRef);
        const lesson = bundle.lesson;
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

        const activity = scoredActivities(bundle).find((item) => item.id === activityId)!;
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
        const activityIndex = session.activityIds.indexOf(activityId);
        if (session.sequenceVersion === 1 && activityIndex > (session.nextActivityIndex ?? 0)) {
          throw new HttpsError("failed-precondition", "Conclua a atividade anterior.");
        }
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
          ...sessionClockPatch(session, new Date()),
          ...(session.sequenceVersion === 1 ? {
            nextActivityIndex: Math.max(session.nextActivityIndex ?? 0,
              activityIndex + (activityCompleted ? 1 : 0)),
          } : {}),
          activityProgress: allProgress,
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        tx.create(attemptRef, {
          schemaVersion: 1,
          contentVersion: bundle.lesson.contentVersion,
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
  if (typeof response.questionId === "string" && typeof response.selectedLabel === "string") {
    return { questionId:response.questionId.slice(0,64), selectedLabel:response.selectedLabel.slice(0,80) };
  }
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
