/**
 * Assessment domain (spec §5: content is configuration-driven). Questions,
 * option weights and placement thresholds all live in Firestore under
 * `assessments/{assessmentId}`; this module only interprets them.
 *
 * Scoring runs server-side from the stored weights — the client sends which
 * option was chosen, never how much it is worth.
 */

export interface AssessmentOption {
  id: string;
  label: string;
  weight: number;
}

export interface AssessmentQuestion {
  id: string;
  /** May contain `{name}`, substituted with the child's name for display. */
  prompt: string;
  order: number;
  options: AssessmentOption[];
}

/**
 * Placement bands, evaluated from the lowest `maxScore` up. The band whose
 * `maxScore` first covers the score wins; scores above every band fall to
 * the highest one.
 */
export interface PlacementRule {
  maxScore: number;
  moduleNumber: number;
  moduleTitle: string;
  description: string;
  tags: string[];
  learningLevel: string;
  courseId: string;
  firstLessonId: string;
}

export interface Assessment {
  id: string;
  title: string;
  published: boolean;
  questions: AssessmentQuestion[];
  placements: PlacementRule[];
}

/** Raised when the submitted answers don't match the stored assessment. */
export class InvalidAnswerError extends Error {}

/** Answers keyed by question id, valued by the chosen option id. */
export type AnswerMap = Record<string, string>;

/**
 * Sums the stored weights of the chosen options. Every question must be
 * answered with an option that exists on that question.
 */
export function scoreAnswers(
  questions: AssessmentQuestion[],
  answers: AnswerMap,
): number {
  if (questions.length === 0) {
    throw new InvalidAnswerError("Assessment has no questions");
  }
  let score = 0;
  for (const question of questions) {
    const chosenId = answers[question.id];
    if (chosenId === undefined) {
      throw new InvalidAnswerError(`Missing answer for ${question.id}`);
    }
    const option = question.options.find((o) => o.id === chosenId);
    if (!option) {
      throw new InvalidAnswerError(
        `Unknown option ${chosenId} for ${question.id}`,
      );
    }
    score += option.weight;
  }
  return score;
}

/** Highest score the assessment can produce — used for progress display. */
export function maxScore(questions: AssessmentQuestion[]): number {
  return questions.reduce(
    (total, question) =>
      total +
      question.options.reduce((best, o) => Math.max(best, o.weight), 0),
    0,
  );
}

export function placementFor(
  placements: PlacementRule[],
  score: number,
): PlacementRule {
  if (placements.length === 0) {
    throw new InvalidAnswerError("Assessment has no placement rules");
  }
  const ordered = [...placements].sort((a, b) => a.maxScore - b.maxScore);
  return ordered.find((rule) => score <= rule.maxScore) ?? ordered[ordered.length - 1];
}

/** Sorts questions into presentation order without mutating the input. */
export function orderedQuestions(
  questions: AssessmentQuestion[],
): AssessmentQuestion[] {
  return [...questions].sort((a, b) => a.order - b.order);
}
