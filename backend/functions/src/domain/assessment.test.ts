import assert from "node:assert/strict";
import { describe, it } from "node:test";

import {
  Assessment,
  InvalidAnswerError,
  maxScore,
  orderedQuestions,
  placementFor,
  scoreAnswers,
} from "./assessment";

const assessment: Assessment = {
  id: "assessment_pre_literacy_v1",
  title: "Avaliação inicial",
  published: true,
  questions: [
    {
      id: "q_letters",
      prompt: "{name} já reconhece algumas letras?",
      order: 1,
      options: [
        { id: "not_yet", label: "Ainda não", weight: 0 },
        { id: "some", label: "Algumas letras", weight: 1 },
        { id: "most", label: "Quase todas", weight: 2 },
      ],
    },
    {
      id: "q_name",
      prompt: "{name} consegue escrever o próprio nome?",
      order: 2,
      options: [
        { id: "not_yet", label: "Ainda não", weight: 0 },
        { id: "with_help", label: "Com ajuda", weight: 1 },
        { id: "alone", label: "Sozinho(a)", weight: 2 },
      ],
    },
  ],
  placements: [
    {
      maxScore: 1,
      moduleNumber: 1,
      moduleTitle: "Coordenação Motora",
      description: "...",
      tags: ["15 min/dia"],
      learningLevel: "pre_literacy",
      courseId: "course_001",
      firstLessonId: "lesson_001",
    },
    {
      maxScore: 3,
      moduleNumber: 3,
      moduleTitle: "Consciência Fonológica",
      description: "...",
      tags: ["15 min/dia"],
      learningLevel: "phonological",
      courseId: "course_001",
      firstLessonId: "lesson_008",
    },
  ],
};

describe("scoreAnswers", () => {
  it("sums the stored weights of the chosen options", () => {
    const score = scoreAnswers(assessment.questions, {
      q_letters: "most",
      q_name: "with_help",
    });
    assert.equal(score, 3);
  });

  it("scores an all-lowest run at zero", () => {
    const score = scoreAnswers(assessment.questions, {
      q_letters: "not_yet",
      q_name: "not_yet",
    });
    assert.equal(score, 0);
  });

  it("ignores weights the client might try to send", () => {
    // Only option ids are consulted; a forged weight in the payload has no
    // path into the score.
    const score = scoreAnswers(assessment.questions, {
      q_letters: "not_yet",
      q_name: "not_yet",
      weight: "999",
    } as Record<string, string>);
    assert.equal(score, 0);
  });

  it("rejects a missing answer", () => {
    assert.throws(
      () => scoreAnswers(assessment.questions, { q_letters: "most" }),
      InvalidAnswerError,
    );
  });

  it("rejects an option that does not belong to the question", () => {
    assert.throws(
      () =>
        scoreAnswers(assessment.questions, {
          q_letters: "alone",
          q_name: "alone",
        }),
      InvalidAnswerError,
    );
  });

  it("rejects an assessment with no questions", () => {
    assert.throws(() => scoreAnswers([], {}), InvalidAnswerError);
  });
});

describe("placementFor", () => {
  it("places a low score in the first band", () => {
    assert.equal(placementFor(assessment.placements, 0).moduleNumber, 1);
    assert.equal(placementFor(assessment.placements, 1).moduleNumber, 1);
  });

  it("places a mid score in the next band", () => {
    assert.equal(placementFor(assessment.placements, 2).moduleNumber, 3);
    assert.equal(placementFor(assessment.placements, 3).moduleNumber, 3);
  });

  it("clamps scores above every band to the highest one", () => {
    assert.equal(placementFor(assessment.placements, 99).moduleNumber, 3);
  });

  it("evaluates bands by threshold, not document order", () => {
    const shuffled = [...assessment.placements].reverse();
    assert.equal(placementFor(shuffled, 0).moduleNumber, 1);
  });

  it("rejects an assessment with no placement rules", () => {
    assert.throws(() => placementFor([], 0), InvalidAnswerError);
  });
});

describe("question helpers", () => {
  it("reports the maximum reachable score", () => {
    assert.equal(maxScore(assessment.questions), 4);
  });

  it("sorts questions by order without mutating the source", () => {
    const source = [assessment.questions[1], assessment.questions[0]];
    const sorted = orderedQuestions(source);
    assert.deepEqual(sorted.map((q) => q.id), ["q_letters", "q_name"]);
    assert.equal(source[0].id, "q_name");
  });
});
