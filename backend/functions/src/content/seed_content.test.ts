import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, it } from "node:test";

/**
 * Integrity checks over the committed seed content (`backend/seed/`).
 *
 * Content is configuration-driven (spec §5), so these files — not app code —
 * define the curriculum. They are meant to be hand-edited by a content
 * editor, which is exactly why their structure and cross-references are
 * verified here rather than discovered in production.
 */
// Resolved from the compiled test in functions/lib/content/.
const seedRoot = join(__dirname, "../../../seed");

const read = <T>(file: string): T =>
  JSON.parse(readFileSync(join(seedRoot, file), "utf8")) as T;

interface SeedDoc {
  id: string;
  published: boolean;
}
interface Course extends SeedDoc {
  moduleIds: string[];
  lessonCount: number;
}
interface Module extends SeedDoc {
  courseId: string;
  number: number;
  title: string;
  firstLessonId: string;
  lessonCount: number;
}
interface Lesson extends SeedDoc {
  courseId: string;
  moduleId: string;
  number: number;
  order: number;
  activityIds: string[];
}
interface Option {
  id: string;
  label: string;
  correct: boolean;
}
interface Activity extends SeedDoc {
  lessonId: string;
  type: "tap" | "match" | "trace" | "listen";
  order: number;
  instruction: string;
  target?: string;
  answer?: string;
  letter?: string;
  speech?: string;
  options?: Option[];
  pairs?: { upper: string; lower: string }[];
  lowercaseOrder?: string[];
}
interface Assessment extends SeedDoc {
  placements: {
    moduleNumber: number;
    moduleTitle: string;
    firstLessonId: string;
  }[];
}

const course = read<Course>("courses/course_001.json");
const modules = read<Module[]>("modules/modules.json");
const lessons = read<Lesson[]>("lessons/lessons.json");
const activities = read<Activity[]>("activities/activities.json");
const assessment = read<Assessment>(
  "assessments/assessment_pre_literacy_v1.json",
);

const ids = (docs: SeedDoc[]) => docs.map((d) => d.id);
const unique = (values: string[]) => new Set(values).size === values.length;

/** The order the app plays a lesson's activities in. */
const PLAY_ORDER = ["tap", "match", "trace", "listen"] as const;

describe("seed content — structure", () => {
  it("every document has an id and is published", () => {
    for (const doc of [course, ...modules, ...lessons, ...activities]) {
      assert.ok(doc.id, "document without an id");
      assert.equal(doc.published, true, `${doc.id} is not published`);
    }
  });

  it("ids are unique within each collection", () => {
    assert.ok(unique(ids(modules)));
    assert.ok(unique(ids(lessons)));
    assert.ok(unique(ids(activities)));
  });

  it("the course lists exactly its modules, in order", () => {
    assert.deepEqual(course.moduleIds, ids(modules));
    assert.equal(course.lessonCount, lessons.length);
  });

  it("modules are numbered contiguously from 1", () => {
    assert.deepEqual(
      modules.map((m) => m.number),
      modules.map((_, index) => index + 1),
    );
  });
});

describe("seed content — references", () => {
  it("every lesson belongs to a module of its course", () => {
    const moduleIds = new Set(ids(modules));
    for (const lesson of lessons) {
      assert.ok(moduleIds.has(lesson.moduleId), `${lesson.id} → ${lesson.moduleId}`);
      assert.equal(lesson.courseId, course.id);
    }
  });

  it("each module's declared lesson range matches its lessons", () => {
    for (const module of modules) {
      const own = lessons
        .filter((lesson) => lesson.moduleId === module.id)
        .sort((a, b) => a.order - b.order);
      assert.equal(own.length, module.lessonCount, `${module.id} lesson count`);
      assert.equal(own[0].id, module.firstLessonId, `${module.id} first lesson`);
      assert.deepEqual(
        own.map((lesson) => lesson.order),
        own.map((_, index) => index + 1),
        `${module.id} lesson order`,
      );
    }
  });

  it("lesson numbers run 1..n across the whole course", () => {
    const numbers = lessons.map((lesson) => lesson.number).sort((a, b) => a - b);
    assert.deepEqual(numbers, lessons.map((_, index) => index + 1));
  });

  it("every activity belongs to a lesson, and lessons list their activities", () => {
    const lessonIds = new Set(ids(lessons));
    for (const activity of activities) {
      assert.ok(lessonIds.has(activity.lessonId), `${activity.id} → ${activity.lessonId}`);
    }
    const activityIds = new Set(ids(activities));
    for (const lesson of lessons) {
      for (const activityId of lesson.activityIds) {
        assert.ok(activityIds.has(activityId), `${lesson.id} → ${activityId}`);
      }
    }
  });

  it("each lesson has the four activities in play order", () => {
    for (const lesson of lessons) {
      const own = activities
        .filter((activity) => activity.lessonId === lesson.id)
        .sort((a, b) => a.order - b.order);
      assert.deepEqual(
        own.map((activity) => activity.type),
        [...PLAY_ORDER],
        `${lesson.id} activity types`,
      );
      assert.deepEqual(
        own.map((activity) => activity.order),
        [1, 2, 3, 4],
        `${lesson.id} activity order`,
      );
      assert.deepEqual(own.map((activity) => activity.id), lesson.activityIds);
    }
  });

  it("assessment placements point at real modules and lessons", () => {
    const lessonIds = new Set(ids(lessons));
    for (const placement of assessment.placements) {
      assert.ok(
        lessonIds.has(placement.firstLessonId),
        `placement → ${placement.firstLessonId}`,
      );
      const module = modules.find((m) => m.number === placement.moduleNumber);
      assert.ok(module, `no module ${placement.moduleNumber}`);
      assert.equal(module.title, placement.moduleTitle);
      assert.equal(module.firstLessonId, placement.firstLessonId);
    }
  });
});

describe("seed content — activity payloads", () => {
  const choiceActivities = activities.filter(
    (activity) => activity.type === "tap" || activity.type === "listen",
  );

  it("choice activities have exactly one correct option", () => {
    for (const activity of choiceActivities) {
      const options = activity.options ?? [];
      assert.ok(options.length >= 3, `${activity.id} needs options`);
      assert.equal(
        options.filter((option) => option.correct).length,
        1,
        `${activity.id} correct count`,
      );
      const labels = options.map((option) => option.label);
      assert.ok(unique(labels), `${activity.id} duplicate options`);
      const expected = activity.target ?? activity.answer;
      assert.equal(
        options.find((option) => option.correct)?.label,
        expected,
        `${activity.id} answer mismatch`,
      );
    }
  });

  it("the answer is not always in the same slot", () => {
    const slots = new Set(
      choiceActivities.map((activity) =>
        (activity.options ?? []).findIndex((option) => option.correct),
      ),
    );
    assert.ok(slots.size > 1, "answers are positionally predictable");
  });

  it("match activities pair each letter with its own lowercase form", () => {
    for (const activity of activities.filter((a) => a.type === "match")) {
      const pairs = activity.pairs ?? [];
      assert.equal(pairs.length, 3, `${activity.id} pair count`);
      for (const pair of pairs) {
        assert.equal(pair.lower, pair.upper.toLowerCase(), activity.id);
      }
      assert.ok(unique(pairs.map((pair) => pair.upper)), `${activity.id} dupes`);
      assert.deepEqual(
        [...(activity.lowercaseOrder ?? [])].sort(),
        pairs.map((pair) => pair.lower).sort(),
        `${activity.id} lowercase column`,
      );
    }
  });

  it("trace and speech activities carry what they need to run", () => {
    for (const activity of activities) {
      assert.ok(activity.instruction.length > 0, `${activity.id} instruction`);
      if (activity.type === "trace") {
        assert.equal(activity.letter?.length, 1, `${activity.id} letter`);
      }
      if (activity.type === "tap" || activity.type === "listen") {
        assert.ok(activity.speech, `${activity.id} needs speech text`);
      }
    }
  });

  it("never shows uppercase I and lowercase l together", () => {
    // They are the same glyph in most fonts, so the child cannot choose.
    for (const activity of activities) {
      const letters = [
        ...(activity.options ?? []).map((option) => option.label),
        ...(activity.pairs ?? []).map((pair) => pair.upper),
      ];
      assert.ok(
        !(letters.includes("I") && letters.includes("L")),
        `${activity.id} mixes I and L`,
      );
    }
  });
});
