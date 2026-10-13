import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { mayCompleteLesson } from "../domain/lesson_completion";
import { scoredActivities } from "../domain/lesson_content";
import { ActivityProgress, isActivityComplete } from "../domain/lesson_sessions";
import { db, paths } from "../lib/firestore";
import { enforceAppCheck, requireAuth, requireString } from "../lib/guards";
import { hasLessonAccess } from "./lesson_access";
import { readLessonBundle, requireSessionBundle } from "./lesson_bundle";

/** Resumes a durable run from server evidence, without crediting offline time. */
export const recoverLessonSession = onCall({ enforceAppCheck }, async (request) => {
  const uid = requireAuth(request);
  const childId = requireString(request.data?.childId, "childId", { maxLength: 64 });
  const sessionId = requireString(request.data?.sessionId, "sessionId", { maxLength: 64 });
  const lessonId = requireString(request.data?.lessonId, "lessonId", { maxLength: 64 });
  const ref = db().collection(paths.sessions(uid)).doc(sessionId);
  return db().runTransaction(async (tx) => {
    const [snapshot, child, progress] = await Promise.all([
      tx.get(ref), tx.get(db().collection(paths.children(uid)).doc(childId)),
      tx.get(db().collection(paths.learningProgress(uid)).doc(`${childId}_${lessonId}`)),
    ]);
    if (!snapshot.exists || !child.exists || snapshot.get("childId") !== childId ||
        snapshot.get("lessonId") !== lessonId) {
      throw new HttpsError("not-found", "Sessão indisponível.");
    }
    const session = snapshot.data()!;
    if (!["active", "paused", "completed"].includes(session.status) ||
        Date.now() - (session.startedAt?.toMillis?.() ?? 0) > 24 * 3600_000) {
      throw new HttpsError("failed-precondition", "Comece uma nova sessão.");
    }
    const bundle = await readLessonBundle(tx, lessonId);
    requireSessionBundle(session, bundle);
    if (!await hasLessonAccess(tx, uid, bundle.lesson)) {
      throw new HttpsError("permission-denied", "Lição indisponível.");
    }
    if (!mayCompleteLesson({ id: lessonId, courseId: String(bundle.lesson.courseId),
      published: bundle.lesson.published === true }, {
      currentCourseId: child.get("currentCourseId"), currentLessonId: child.get("currentLessonId"),
    }, progress.get("status") === "completed")) {
      throw new HttpsError("failed-precondition", "Lição fora do percurso.");
    }
    const activities = scoredActivities(bundle);
    const progressByActivity = (session.activityProgress ?? {}) as Record<string, ActivityProgress>;
    // Recover only confirmed progress. The local route/cursor is never trusted.
    const pendingIndex = activities.findIndex((activity) =>
      !isActivityComplete(activity, progressByActivity[activity.id]));
    const nextActivityIndex = pendingIndex < 0 ? activities.length : pendingIndex;
    const lastLifecycleSequence = (session.lastLifecycleSequence ?? 0) + 1;
    if (session.status !== "completed") {
      tx.update(ref, { status: "active", nextActivityIndex, lastLifecycleSequence,
        lastActiveAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
    }
    return { ok: true, sessionId, lessonId, childId, contentVersion: bundle.lesson.contentVersion,
      status: session.status === "completed" ? "completed" : "active", nextActivityIndex,
      lastLifecycleSequence, activityProgress: progressByActivity };
  });
});
