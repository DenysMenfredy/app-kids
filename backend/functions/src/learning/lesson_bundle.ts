import { Transaction } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { LessonBundle, lessonFingerprint, lessonPublicationProblem } from "../domain/lesson_content";
import { ActivityDocument } from "../domain/lesson_sessions";
import { db, paths } from "../lib/firestore";

/** Reads the manifest, exercises and optional story in one consistent transaction. */
export async function readLessonBundle(tx: Transaction, lessonId: string, published = true): Promise<LessonBundle> {
  const lessonSnap = await tx.get(db().collection(paths.lessons).doc(lessonId));
  const lesson = lessonSnap.data();
  if (!lesson) throw new HttpsError("not-found", "Lição indisponível.");
  const ids = lesson.activityIds;
  if (!Array.isArray(ids) || ![4, 5].includes(ids.length) ||
      ids.some((id) => typeof id !== "string" || !/^[A-Za-z0-9_-]{1,64}$/.test(id))) {
    throw new HttpsError("failed-precondition", "Manifesto da lição inválido.");
  }
  const snaps = await tx.getAll(...ids.map((id) => db().collection(paths.activities).doc(id)));
  const activities = snaps.map((snap) => ({ ...snap.data(), id: snap.id })) as ActivityDocument[];
  const storyId = activities[4]?.storyId;
  let story: Record<string, unknown> | null = null;
  if (storyId !== undefined) {
    if (typeof storyId !== "string" || !/^[A-Za-z0-9_-]{1,64}$/.test(storyId)) {
      throw new HttpsError("failed-precondition", "História inválida.");
    }
    const snap = await tx.get(db().collection(paths.stories).doc(storyId));
    story = snap.exists ? { ...snap.data(), id: snap.id } : null;
  }
  const bundle = { lesson, activities, story };
  const problem = lessonPublicationProblem(lessonId, bundle);
  if (problem || (published && (lesson.published !== true ||
      activities.some((activity) => activity.published !== true) ||
      (story && story.published !== true)))) {
    throw new HttpsError("failed-precondition", problem ?? "Conteúdo indisponível.");
  }
  return bundle;
}

/** A content edit cannot change the meaning of an in-flight scored session. */
export function requireSessionBundle(session: FirebaseFirestore.DocumentData, bundle: LessonBundle): void {
  const ids = session.activityIds;
  if (!Array.isArray(ids) || JSON.stringify(ids) !== JSON.stringify(bundle.lesson.activityIds) ||
      (session.contentFingerprint && session.contentFingerprint !== lessonFingerprint(bundle))) {
    throw new HttpsError("failed-precondition", "Lição atualizada; comece uma nova sessão.");
  }
}
