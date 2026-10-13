import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { mayCompleteLesson } from "../domain/lesson_completion";
import { validTimezone } from "../domain/active_time";
import { db, paths } from "../lib/firestore";
import { enforceAppCheck, requireAuth, requireString } from "../lib/guards";
import { hasLessonAccess } from "./lesson_access";
import { readLessonBundle, requireSessionBundle } from "./lesson_bundle";
import { lessonFingerprint } from "../domain/lesson_content";
import { createHash } from "node:crypto";

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
    const progressRef = firestore
      .collection(paths.learningProgress(uid))
      .doc(`${childId}_${lessonId}`);
    const sessions = firestore.collection(paths.sessions(uid));
    // A lost response must not create a second run on retry. Legacy callers
    // can still omit the key; current clients persist it before this call.
    const requestId = request.data?.requestId;
    if (requestId !== undefined && (typeof requestId !== "string" ||
        !/^[A-Za-z0-9_-]{1,64}$/.test(requestId))) {
      throw new HttpsError("invalid-argument", "Request ID inválido.");
    }
    const sessionRef = requestId === undefined ? sessions.doc() : sessions.doc(
      createHash("sha256").update(requestId).digest("hex"),
    );
    await firestore.runTransaction(async (tx) => {
      const [childSnap, progressSnap, parentSnap, existingSession] =
        await Promise.all([
          tx.get(childRef),
          tx.get(progressRef),
          tx.get(firestore.doc(paths.user(uid))),
          tx.get(sessionRef),
        ]);

      if (!childSnap.exists) {
        throw new HttpsError("not-found", "Perfil da criança não encontrado.");
      }
      const bundle = await readLessonBundle(tx, lessonId);
      const lesson = bundle.lesson;
      const expectedVersion = request.data?.contentVersion;
      if (expectedVersion !== undefined && (!Number.isSafeInteger(expectedVersion) ||
          expectedVersion !== lesson.contentVersion)) {
        throw new HttpsError("failed-precondition", "Lição atualizada; abra a lição novamente.");
      }
      if (!await hasLessonAccess(tx, uid, lesson)) {
        throw new HttpsError("permission-denied", "Esta lição exige Premium.");
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

      if (existingSession.exists) {
        if (existingSession.get("childId") !== childId ||
            existingSession.get("lessonId") !== lessonId ||
            (request.data?.contentVersion !== undefined &&
              existingSession.get("contentVersion") !== request.data.contentVersion)) {
          throw new HttpsError("invalid-argument", "Request ID já utilizado.");
        }
        requireSessionBundle(existingSession.data()!, bundle);
        if (!["active", "paused", "completed"].includes(existingSession.get("status")) ||
            Date.now() - (existingSession.get("startedAt")?.toMillis?.() ?? 0) > 24 * 3600_000) {
          throw new HttpsError("failed-precondition", "Comece uma nova sessão.");
        }
        return;
      }
      tx.create(sessionRef, {
        schemaVersion: 1,
        childId,
        lessonId,
        activityIds: bundle.activities.map((activity) => activity.id),
        contentVersion: lesson.contentVersion,
        contentFingerprint: lessonFingerprint(bundle),
        activityProgress: {},
        sequenceVersion: 1,
        nextActivityIndex: 0,
        status: "active",
        timingVersion: 1,
        timezone: validTimezone(parentSnap.get("timezone")),
        activeMillisecondsByDate: {},
        lastActiveAt: FieldValue.serverTimestamp(),
        lastLifecycleSequence: 0,
        startedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return { sessionId: sessionRef.id };
  },
);
