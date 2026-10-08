import { Firestore } from "firebase-admin/firestore";

import { paths } from "../lib/firestore";

/**
 * Finds the lesson after [lessonNumber] in [courseId].
 *
 * Lessons carry a `number` running 1..n within a course. The course filter
 * prevents a lesson from another course becoming this child's next lesson.
 */
export async function findNextLessonId(
  firestore: Firestore,
  courseId: string,
  lessonNumber: number,
): Promise<string | null> {
  const next = await firestore
    .collection(paths.lessons)
    .where("courseId", "==", courseId)
    .where("number", "==", lessonNumber + 1)
    .where("published", "==", true)
    .limit(1)
    .get();

  return next.empty ? null : next.docs[0].id;
}
