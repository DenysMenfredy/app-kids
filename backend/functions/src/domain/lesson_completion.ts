/** Server-side eligibility for a first completion or a replay.
 *
 * A published ID alone is not enough: otherwise a caller can submit any
 * lesson in the catalog and mint a reward without reaching it. Completed
 * lessons may be replayed, but the reward transaction still grants only the
 * first completion for that child/lesson pair.
 */
export function mayCompleteLesson(
  lesson: { id: string; courseId: string; published: boolean } | null,
  child: { currentCourseId?: string; currentLessonId?: string } | null,
  completedBefore: boolean,
): boolean {
  return lesson !== null &&
    lesson.published === true &&
    child !== null &&
    child.currentCourseId === lesson.courseId &&
    (child.currentLessonId === lesson.id || completedBefore);
}
