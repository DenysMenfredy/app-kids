import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { db, paths } from "../lib/firestore";
import { enforceAppCheck, requireAuth, requireString } from "../lib/guards";
import { hasLessonAccess } from "./lesson_access";
import { sessionClockPatch } from "./session_clock";

/** Ordered lifecycle commands make a retried pause/resume/heartbeat harmless. */
export const updateLessonSession = onCall({ enforceAppCheck }, async (request) => {
  const uid = requireAuth(request);
  const childId = requireString(request.data?.childId, "childId", { maxLength: 64 });
  const sessionId = requireString(request.data?.sessionId, "sessionId", { maxLength: 64 });
  const action = request.data?.action;
  const sequence = request.data?.sequence;
  if (!["heartbeat", "pause", "resume", "abandon"].includes(action) ||
      !Number.isSafeInteger(sequence) || sequence < 1) {
    throw new HttpsError("invalid-argument", "Comando de sessão inválido.");
  }
  const ref = db().collection(paths.sessions(uid)).doc(sessionId);
  return db().runTransaction(async (tx) => {
    const [sessionSnap, child] = await Promise.all([
      tx.get(ref), tx.get(db().collection(paths.children(uid)).doc(childId)),
    ]);
    if (!child.exists || !sessionSnap.exists || sessionSnap.get("childId") !== childId) {
      throw new HttpsError("not-found", "Sessão indisponível.");
    }
    const session = sessionSnap.data()!;
    if (sequence <= (session.lastLifecycleSequence ?? 0)) return { ok: true, status: session.status };
    if (!["active", "paused"].includes(session.status)) {
      throw new HttpsError("failed-precondition", "Sessão encerrada.");
    }
    // Pausing/abandoning is always allowed; renewed access is checked on resume.
    if (action === "heartbeat" || action === "resume") {
      if (Date.now() - (session.startedAt?.toMillis?.() ?? 0) > 24 * 3600_000) {
        throw new HttpsError("failed-precondition", "Comece uma nova sessão.");
      }
      const lesson = await tx.get(db().collection(paths.lessons).doc(session.lessonId));
      if (!lesson.exists || lesson.get("published") !== true ||
          !await hasLessonAccess(tx, uid, lesson.data()!)) {
        throw new HttpsError("permission-denied", "Lição indisponível.");
      }
    }
    if (action === "heartbeat" && session.status !== "active") {
      throw new HttpsError("failed-precondition", "Sessão pausada.");
    }
    const status = action === "pause" ? "paused" : action === "abandon" ? "abandoned"
      : action === "resume" ? "active" : session.status;
    tx.update(ref, { ...sessionClockPatch(session, new Date()), status,
      lastLifecycleSequence: sequence, updatedAt: FieldValue.serverTimestamp() });
    return { ok: true, status };
  });
});
