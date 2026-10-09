export interface ActivityDocument {
  id: string;
  type: string;
  [key: string]: unknown;
}

export interface ActivityProgress {
  attempts: number;
  correctAnswers: number;
  wrongAnswers: number;
  completed: boolean;
  completedItems: string[];
}

export interface LessonStats {
  durationSeconds: number;
  score: number;
  attempts: number;
  correctAnswers: number;
  wrongAnswers: number;
}

export class InvalidActivityResponseError extends Error {
  constructor() {
    super("Activity response is invalid");
    this.name = "InvalidActivityResponseError";
  }
}

/** Scores only against the trusted, published activity document. */
export function scoreActivityResponse(
  activity: ActivityDocument,
  rawResponse: unknown,
): { correct: boolean; completionKey: string | null } {
  const response = asRecord(rawResponse);
  switch (activity.type) {
    case "tap":
    case "listen": {
      const selectedLabel = boundedString(response.selectedLabel, 80);
      const options = asArray(activity.options);
      const option = options
        .map(asRecord)
        .find((candidate) => candidate.label === selectedLabel);
      if (!option) throw new InvalidActivityResponseError();
      const correct = option.correct === true;
      return { correct, completionKey: correct ? "complete" : null };
    }
    case "match": {
      const upper = boundedString(response.upper, 16);
      const lower = boundedString(response.lower, 16);
      const pairs = asArray(activity.pairs);
      const pair = pairs
        .map(asRecord)
        .find((candidate) => candidate.upper === upper);
      const correct = pair?.lower === lower;
      return { correct, completionKey: correct ? upper : null };
    }
    case "trace": {
      const strokeCount = boundedInteger(response.strokeCount, 1, 20);
      const pointCount = boundedInteger(response.pointCount, 2, 1_000);
      const durationMillis = boundedInteger(response.durationMillis, 100, 120_000);
      const correct = strokeCount > 0 && pointCount >= 2 && durationMillis >= 100;
      return { correct, completionKey: correct ? "complete" : null };
    }
    default:
      throw new InvalidActivityResponseError();
  }
}

/** A match is complete only after each published pair has been matched. */
export function isActivityComplete(
  activity: ActivityDocument,
  progress: Partial<ActivityProgress> | undefined,
): boolean {
  if (!progress) return false;
  if (activity.type !== "match") return progress.completed === true;

  const pairs = asArray(activity.pairs).map(asRecord);
  const expected = pairs
    .map((pair) => pair.upper)
    .filter((upper): upper is string => typeof upper === "string");
  const completed = new Set(progress.completedItems ?? []);
  return expected.length > 0 && expected.every((upper) => completed.has(upper));
}

/** Derives persisted lesson totals from server-scored session evidence. */
export function summarizeLessonSession(
  activities: ActivityDocument[],
  progressByActivity: Record<string, Partial<ActivityProgress>>,
  activeSeconds: number,
): LessonStats {
  const complete = activities.length === 4 &&
    activities.every((activity) =>
      isActivityComplete(activity, progressByActivity[activity.id]),
    );
  if (!complete) throw new Error("Lesson session is incomplete");

  const totals = activities.reduce(
    (sum, activity) => {
      const progress = progressByActivity[activity.id];
      sum.attempts += nonNegativeInteger(progress?.attempts);
      sum.correctAnswers += nonNegativeInteger(progress?.correctAnswers);
      sum.wrongAnswers += nonNegativeInteger(progress?.wrongAnswers);
      return sum;
    },
    { attempts: 0, correctAnswers: 0, wrongAnswers: 0 },
  );
  const durationSeconds = Math.max(
    0,
    Math.min(30 * 60, Math.floor(activeSeconds)),
  );
  return {
    ...totals,
    durationSeconds,
    score: totals.attempts === 0
      ? 0
      : Math.round(100 * totals.correctAnswers / totals.attempts),
  };
}

function asRecord(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new InvalidActivityResponseError();
  }
  return value as Record<string, unknown>;
}

function asArray(value: unknown): unknown[] {
  if (!Array.isArray(value)) throw new InvalidActivityResponseError();
  return value;
}

function boundedString(value: unknown, maxLength: number): string {
  if (typeof value !== "string" || value.length === 0 || value.length > maxLength) {
    throw new InvalidActivityResponseError();
  }
  return value;
}

function boundedInteger(value: unknown, min: number, max: number): number {
  if (
    typeof value !== "number" ||
    !Number.isInteger(value) ||
    value < min ||
    value > max
  ) {
    throw new InvalidActivityResponseError();
  }
  return value;
}

function nonNegativeInteger(value: unknown): number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0
    ? value
    : 0;
}
