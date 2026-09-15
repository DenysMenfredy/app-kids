import { Firestore } from "firebase-admin/firestore";

import { paths } from "../lib/firestore";

/**
 * Finds the lesson that follows [lessonId] in the course.
 *
 * Lessons carry a `number` running 1..n across the whole course, so the next
 * one is simply the next number — no reliance on the shape of the id. Null
 * when the lesson is unknown or the child has reached the end of the course.
 */
export async function findNextLessonId(
  firestore: Firestore,
  lessonId: string,
): Promise<string | null> {
  const lesson = await firestore.collection(paths.lessons).doc(lessonId).get();
  const number = lesson.get("number") as number | undefined;
  if (typeof number !== "number") return null;

  const next = await firestore
    .collection(paths.lessons)
    .where("number", "==", number + 1)
    .where("published", "==", true)
    .limit(1)
    .get();

  return next.empty ? null : next.docs[0].id;
}
