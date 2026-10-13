import { createHash } from "node:crypto";
import { BOOK_ILLUSTRATIONS } from "./books";
import { ActivityDocument } from "./lesson_sessions";

export interface LessonBundle {
  lesson: Record<string, unknown>;
  activities: ActivityDocument[];
  story: Record<string, unknown> | null;
}

const text = (value: unknown, max: number): value is string =>
  typeof value === "string" && value.trim().length > 0 && value.length <= max;
const record = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);
const versioned = (value: Record<string, unknown>): boolean =>
  value.schemaVersion === 1 && Number.isSafeInteger(value.contentVersion) &&
  Number(value.contentVersion) >= 1;

/** Validates the complete story before publication or session creation. */
export function storyPublicationProblem(story: Record<string, unknown>): string | null {
  if (!versioned(story) || !text(story.id, 64) || !text(story.lessonId, 64) ||
      !text(story.title, 100) || !Array.isArray(story.pages) ||
      story.pages.length < 1 || story.pages.length > 12 ||
      !Array.isArray(story.questions) || story.questions.length < 1 ||
      story.questions.length > 8) return "História incompleta ou sem versão suportada.";
  const pages = new Set();
  for (const page of story.pages) {
    if (!record(page) || !text(page.id, 64) || pages.has(page.id) ||
        !text(page.text, 1200) ||
        !BOOK_ILLUSTRATIONS.includes(page.illustration as typeof BOOK_ILLUSTRATIONS[number]) ||
        "audioUrl" in page || "imageUrl" in page) return "Página ou mídia da história inválida.";
    pages.add(page.id);
  }
  const questions = new Set();
  for (const question of story.questions) {
    if (!record(question) || !text(question.id, 64) || questions.has(question.id) ||
        !text(question.question, 300) || !Array.isArray(question.options) ||
        question.options.length < 2 || question.options.length > 4 ||
        question.options.some((option) => !text(option, 80)) ||
        new Set(question.options).size !== question.options.length ||
        !question.options.includes(question.answer)) return "Pergunta ou resposta da história inválida.";
    questions.add(question.id);
  }
  return null;
}

/** Four original exercises, optionally followed by one comprehension story. */
export function lessonPublicationProblem(lessonId: string, bundle: LessonBundle): string | null {
  const { lesson, activities, story } = bundle;
  const expected = story ? ["tap", "match", "trace", "listen", "story"]
    : ["tap", "match", "trace", "listen"];
  if (!versioned(lesson) || lesson.id !== lessonId || !text(lesson.title, 150) ||
      !text(lesson.courseId, 64) || !text(lesson.moduleId, 64) ||
      !Array.isArray(lesson.activityIds) || lesson.activityIds.length !== expected.length ||
      activities.length !== expected.length ||
      new Set(lesson.activityIds).size !== expected.length) return "Manifesto da lição inválido.";
  for (const [index, activity] of activities.entries()) {
    if (!versioned(activity) || activity.id !== lesson.activityIds[index] ||
        activity.lessonId !== lessonId || activity.order !== index + 1 ||
        activity.type !== expected[index] || !text(activity.instruction, 300)) {
      return "Tipo, ordem ou versão de atividade inválida.";
    }
    if (activity.type === "tap" || activity.type === "listen") {
      const options = activity.options;
      if (!text(activity.speech, 300) || !Array.isArray(options) ||
          options.length < 2 || options.length > 6 ||
          options.some((option) => !record(option) || !text(option.label, 80) || typeof option.correct !== "boolean") ||
          new Set(options.map((option) => option.label)).size !== options.length ||
          options.filter((option) => option.correct === true).length !== 1 ||
          options.find((option) => option.correct === true)?.label !==
            (activity.type === "tap" ? activity.target : activity.answer)) return "Opções da atividade inválidas.";
    }
    if (activity.type === "match") {
      const pairs = activity.pairs;
      if (!Array.isArray(pairs) || pairs.length < 1 || pairs.length > 8 ||
          pairs.some((pair) => !record(pair) || !text(pair.upper, 16) || !text(pair.lower, 16)) ||
          new Set(pairs.map((pair) => pair.upper)).size !== pairs.length ||
          new Set(pairs.map((pair) => pair.lower)).size !== pairs.length ||
          !Array.isArray(activity.lowercaseOrder) ||
          JSON.stringify([...activity.lowercaseOrder].sort()) !== JSON.stringify(pairs.map((pair) => pair.lower).sort())) return "Pares da atividade inválidos.";
    }
    if (activity.type === "trace" && (!text(activity.letter, 2) || !text(activity.speech, 300))) {
      return "Traçado da atividade inválido.";
    }
    if (activity.type === "story" && (activity.storyId !== story?.id || story?.lessonId !== lessonId)) {
      return "História fora da lição.";
    }
  }
  return story ? storyPublicationProblem(story) : null;
}

/** Content identity ignores publication/audit fields, never answer changes. */
export function lessonFingerprint(bundle: LessonBundle): string {
  const clean = (value: Record<string, unknown>) => Object.fromEntries(
    Object.entries(value).filter(([key]) => !["published", "updatedAt", "updatedBy", "createdAt"].includes(key)),
  );
  function canonical(value: unknown): unknown {
    if (Array.isArray(value)) return value.map(canonical);
    if (record(value)) return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonical(value[key])]));
    return value;
  }
  return createHash("sha256").update(JSON.stringify(canonical({
    lesson: clean(bundle.lesson), activities: bundle.activities.map(clean),
    story: bundle.story ? clean(bundle.story) : null,
  }))).digest("hex");
}

export function scoredActivities(bundle: LessonBundle): ActivityDocument[] {
  return bundle.activities.map((activity) => activity.type === "story"
    ? { ...activity, questions: bundle.story?.questions } : activity);
}
