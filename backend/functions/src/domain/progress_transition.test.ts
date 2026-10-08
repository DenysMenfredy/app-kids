import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { mayUpdateLessonProgress } from "./progress_transition";

const eligible = {
  childExists: true,
  lessonId: "lesson_001",
  lessonCourseId: "course_001",
  lessonPublished: true,
  currentCourseId: "course_001",
  currentLessonId: "lesson_001",
  existingStatus: "in_progress",
};

describe("lesson progress transitions", () => {
  it("allows progress for the child's assigned published lesson", () => {
    assert.equal(mayUpdateLessonProgress(eligible), true);
  });

  it("rejects missing children, unpublished lessons and other courses", () => {
    assert.equal(
      mayUpdateLessonProgress({ ...eligible, childExists: false }),
      false,
    );
    assert.equal(
      mayUpdateLessonProgress({ ...eligible, lessonPublished: false }),
      false,
    );
    assert.equal(
      mayUpdateLessonProgress({ ...eligible, currentCourseId: "course_002" }),
      false,
    );
  });

  it("rejects a lesson outside the assigned position", () => {
    assert.equal(
      mayUpdateLessonProgress({ ...eligible, currentLessonId: "lesson_002" }),
      false,
    );
  });

  it("never lets progress updates reopen a completed lesson", () => {
    assert.equal(
      mayUpdateLessonProgress({ ...eligible, existingStatus: "completed" }),
      false,
    );
  });
});
