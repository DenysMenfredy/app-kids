import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  ActivityDocument,
  isActivityComplete,
  InvalidActivityResponseError,
  scoreActivityResponse,
  summarizeLessonSession,
} from "./lesson_sessions";

const tap: ActivityDocument = {
  id: "tap",
  type: "tap",
  options: [
    { label: "L", correct: false },
    { label: "A", correct: true },
  ],
};

const match: ActivityDocument = {
  id: "match",
  type: "match",
  pairs: [
    { upper: "A", lower: "a" },
    { upper: "L", lower: "l" },
  ],
};

const trace: ActivityDocument = { id: "trace", type: "trace" };
const listen: ActivityDocument = {
  id: "listen",
  type: "listen",
  options: [
    { label: "ASA", correct: true },
    { label: "AVE", correct: false },
  ],
};

describe("server-scored lesson activities", () => {
  it("scores tap and listen answers from published option labels", () => {
    assert.deepEqual(scoreActivityResponse(tap, { selectedLabel: "A" }), {
      correct: true,
      completionKey: "complete",
    });
    assert.equal(
      scoreActivityResponse(listen, { selectedLabel: "AVE" }).correct,
      false,
    );
  });

  it("scores only the exact published uppercase/lowercase match", () => {
    assert.deepEqual(scoreActivityResponse(match, { upper: "A", lower: "a" }), {
      correct: true,
      completionKey: "A",
    });
    assert.equal(
      scoreActivityResponse(match, { upper: "A", lower: "l" }).correct,
      false,
    );
  });

  it("requires bounded trace gesture evidence and rejects malformed answers", () => {
    assert.equal(
      scoreActivityResponse(trace, {
        strokeCount: 1,
        pointCount: 8,
        durationMillis: 400,
      }).correct,
      true,
    );
    assert.throws(
      () => scoreActivityResponse(trace, {
        strokeCount: 1,
        pointCount: 1,
        durationMillis: 400,
      }),
      InvalidActivityResponseError,
    );
    assert.throws(
      () => scoreActivityResponse(tap, { selectedLabel: "not-an-option" }),
      InvalidActivityResponseError,
    );
  });

  it("requires all published match pairs before marking the activity complete", () => {
    assert.equal(isActivityComplete(match, {
      attempts: 1,
      correctAnswers: 1,
      wrongAnswers: 0,
      completed: false,
      completedItems: ["A"],
    }), false);
    assert.equal(isActivityComplete(match, {
      attempts: 2,
      correctAnswers: 2,
      wrongAnswers: 0,
      completed: false,
      completedItems: ["A", "L"],
    }), true);
  });

  it("derives stats only after every activity has server-scored completion", () => {
    const activities = [tap, match, trace, listen];
    assert.throws(
      () => summarizeLessonSession(activities, {}, new Date(0), new Date(5000)),
      /incomplete/,
    );
    const stats = summarizeLessonSession(
      activities,
      {
        tap: { attempts: 2, correctAnswers: 1, wrongAnswers: 1, completed: true },
        match: {
          attempts: 2,
          correctAnswers: 2,
          wrongAnswers: 0,
          completed: true,
          completedItems: ["A", "L"],
        },
        trace: { attempts: 1, correctAnswers: 1, wrongAnswers: 0, completed: true },
        listen: { attempts: 1, correctAnswers: 1, wrongAnswers: 0, completed: true },
      },
      new Date(0),
      new Date(65_000),
    );
    assert.deepEqual(stats, {
      durationSeconds: 65,
      score: 83,
      attempts: 6,
      correctAnswers: 5,
      wrongAnswers: 1,
    });
  });
});
