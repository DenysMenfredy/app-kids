import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { mayCompleteLesson } from "../domain/lesson_completion";
import { db, paths } from "../lib/firestore";
import { enforceAppCheck, requireAuth, requireString } from "../lib/guards";
import { hasLessonAccess } from "./lesson_access";

const EXPECTED_ACTIVITY_TYPES = ["tap", "match", "trace", "listen"];

/** Creates the server-owned evidence record for one lesson run. */
export const startLessonSession = onCall(
  { enforceAppCheck },
  async (request) => {
    const uid = requireAuth(request);
    const childId = requireString(request.data?.childId, "childId", {
      maxLength: 64,
    });
    const lessonId = requireString(request.data?.lessonId, "lessonId", {
      maxLength: 64,
    });

    const firestore = db();
    const childRef = firestore.collection(paths.children(uid)).doc(childId);
    const lessonRef = firestore.collection(paths.lessons).doc(lessonId);
    const progressRef = firestore
      .collection(paths.learningProgress(uid))
      .doc(`${childId}_${lessonId}`);
    const activities = await firestore
      .collection(paths.activities)
      .where("lessonId", "==", lessonId)
      .get();
    const activityDocs = activities.docs
      .filter((doc) => doc.get("published") === true)
      .sort((a, b) => Number(a.get("order")) - Number(b.get("order")));

    if (
      activityDocs.length !== EXPECTED_ACTIVITY_TYPES.length ||
      activityDocs.some((doc, index) => doc.get("type") !== EXPECTED_ACTIVITY_TYPES[index])
    ) {
      throw new HttpsError("failed-precondition", "Conteúdo da lição incompleto.");
    }

    const sessions = firestore.collection(paths.sessions(uid));
    const sessionRef = sessions.doc();
    await firestore.runTransaction(async (tx) => {
      const activityRefs = activityDocs.map((doc) => doc.ref);
      const [childSnap, lessonSnap, progressSnap, ...currentActivities] =
        await Promise.all([
          tx.get(childRef),
          tx.get(lessonRef),
          tx.get(progressRef),
          ...activityRefs.map((ref) => tx.get(ref)),
        ]);

      if (!childSnap.exists) {
        throw new HttpsError("not-found", "Perfil da criança não encontrado.");
      }
      const lesson = lessonSnap.data();
      if (!lesson || lesson.published !== true) {
        throw new HttpsError("not-found", "Lição indisponível.");
      }
      const listedActivityIds = lesson.activityIds;
      if (
        !Array.isArray(listedActivityIds) ||
        listedActivityIds.length !== activityDocs.length ||
        listedActivityIds.some((id: unknown, index: number) =>
          id !== activityDocs[index].id,
        )
      ) {
        throw new HttpsError("failed-precondition", "Manifesto da lição inválido.");
      }
      if (!await hasLessonAccess(tx, uid, lesson)) {
        throw new HttpsError("permission-denied", "Esta lição exige Premium.");
      }
      if (currentActivities.some((activity) =>
        !activity.exists || activity.get("published") !== true ||
        activity.get("lessonId") !== lessonId,
      )) {
        throw new HttpsError("aborted", "Conteúdo alterado; tente novamente.");
      }
      if (!mayCompleteLesson(
        {
          id: lessonId,
          courseId: typeof lesson.courseId === "string" ? lesson.courseId : "",
          published: lesson.published === true,
        },
        {
          currentCourseId: childSnap.get("currentCourseId"),
          currentLessonId: childSnap.get("currentLessonId"),
        },
        progressSnap.get("status") === "completed",
      )) {
        throw new HttpsError(
          "failed-precondition",
          "Lição fora do percurso da criança.",
        );
      }

      tx.create(sessionRef, {
        childId,
        lessonId,
        activityIds: activityDocs.map((doc) => doc.id),
        activityProgress: {},
        status: "active",
        startedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return { sessionId: sessionRef.id };
  },
);
