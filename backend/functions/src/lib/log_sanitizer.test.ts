import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { redactChildIdentifiers } from "./log_sanitizer";

describe("redactChildIdentifiers", () => {
  it("removes child identifiers recursively but preserves useful metrics", () => {
    assert.deepEqual(
      redactChildIdentifiers({
        lessonId: "lesson_001",
        status: "completed",
        params: {
          childId: "child-secret",
          nested: [{ child_profile_id: "also-secret", score: 90 }],
        },
      }),
      {
        lessonId: "lesson_001",
        status: "completed",
        params: { nested: [{ score: 90 }] },
      },
    );
  });

  it("leaves primitive and date values intact", () => {
    const timestamp = new Date("2026-10-08T12:00:00.000Z");
    assert.deepEqual(redactChildIdentifiers({ timestamp, count: 2 }), {
      timestamp,
      count: 2,
    });
  });
});
