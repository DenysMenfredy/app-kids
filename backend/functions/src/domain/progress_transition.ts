/**
 * A lesson progress update is valid only for the child's assigned lesson.
 * Completed progress is terminal so a client cannot reset the reward guard
 * and claim the same lesson again.
 */
export function mayUpdateLessonProgress(input: {
  childExists: boolean;
  lessonId: string;
  lessonCourseId: string | null;
  lessonPublished: boolean;
  currentCourseId: string | null;
  currentLessonId: string | null;
  existingStatus: string | null;
}): boolean {
  return (
    input.childExists &&
    input.lessonPublished &&
    input.lessonCourseId !== null &&
    input.currentCourseId === input.lessonCourseId &&
    input.currentLessonId === input.lessonId &&
    input.existingStatus !== "completed"
  );
}
