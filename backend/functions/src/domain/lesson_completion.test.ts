import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { mayCompleteLesson } from "./lesson_completion";

const lesson = { id: "lesson_010", courseId: "course_001", published: true };
const child = { currentCourseId: "course_001", currentLessonId: "lesson_010" };

describe("lesson completion eligibility", () => {
  it("accepts the child's current published lesson", () => {
    assert.equal(mayCompleteLesson(lesson, child, false), true);
  });

  it("accepts a replay only when this child completed it before", () => {
    const advanced = { ...child, currentLessonId: "lesson_011" };
    assert.equal(mayCompleteLesson(lesson, advanced, false), false);
    assert.equal(mayCompleteLesson(lesson, advanced, true), true);
  });

  it("rejects invented, unpublished and other-course lessons", () => {
    assert.equal(mayCompleteLesson(null, child, false), false);
    assert.equal(mayCompleteLesson({ ...lesson, published: false }, child, false), false);
    assert.equal(mayCompleteLesson({ ...lesson, courseId: "course_002" }, child, false), false);
    assert.equal(mayCompleteLesson(lesson, null, false), false);
  });

  it("does not grant a lesson to an unplaced child", () => {
    assert.equal(mayCompleteLesson(lesson, { currentLessonId: "lesson_010" }, false), false);
  });
});
