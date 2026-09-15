/**
 * Expands the authored curriculum into the Firestore documents under seed/.
 *
 * `content/curriculum.json` holds the teaching decisions — which letter each
 * lesson introduces, which distractors contrast with it, which word the child
 * hears. This script only turns those into documents; it makes no editorial
 * choices of its own, so regenerating never changes the curriculum.
 *
 *   npm run seed:build
 */
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "../..");
const curriculum = JSON.parse(
  readFileSync(join(root, "content/curriculum.json"), "utf8"),
);

const pad = (n) => String(n).padStart(3, "0");
const lessonId = (n) => `lesson_${pad(n)}`;
const moduleId = (n) => `module_${pad(n)}`;
const { courseId } = curriculum;

/** Rotates the answer through the slots so it is never positionally obvious. */
const place = (correct, others, slot) => {
  const out = [...others];
  out.splice(slot % (others.length + 1), 0, correct);
  return out;
};
const option = (value, correct) => ({ id: value, label: value, correct });

const modules = [];
const lessons = [];
const activities = [];

let lessonNumber = 0;
for (const module of curriculum.modules) {
  const firstLesson = lessonNumber + 1;
  modules.push({
    id: moduleId(module.number),
    courseId,
    number: module.number,
    title: module.title,
    description: module.description,
    lessonTheme: module.lessonTheme,
    firstLessonId: lessonId(firstLesson),
    lessonCount: module.lessons.length,
    estimatedWeeks: module.estimatedWeeks,
    order: module.number,
    published: true,
  });

  module.lessons.forEach((lesson, index) => {
    lessonNumber += 1;
    const n = lessonNumber;
    const { letter, letterName, word } = lesson;
    const ids = ["tap", "match", "trace", "listen"].map(
      (type) => `activity_${pad(n)}_${type}`,
    );

    lessons.push({
      id: lessonId(n),
      courseId,
      moduleId: moduleId(module.number),
      number: n,
      order: index + 1,
      title: `Vamos brincar com a letra ${letter}!`,
      theme: module.lessonTheme,
      estimatedMinutes: 15,
      activityIds: ids,
      published: true,
    });

    const base = {
      lessonId: lessonId(n),
      courseId,
      difficulty: module.number,
      published: true,
    };

    activities.push({
      ...base,
      id: ids[0],
      type: "tap",
      order: 1,
      instruction: `Toque na letra ${letter}`,
      speech: `Toque na letra ${letterName}`,
      target: letter,
      options: place(
        option(letter, true),
        lesson.tap.map((d) => option(d, false)),
        n,
      ),
    });

    activities.push({
      ...base,
      id: ids[1],
      type: "match",
      order: 2,
      instruction: "Ligue as letras iguais",
      hint: "Toque na letra grande e depois na pequena",
      pairs: lesson.trio.map((upper) => ({
        upper,
        lower: upper.toLowerCase(),
      })),
      // Right column shifted, so the pairs aren't a straight line across.
      lowercaseOrder: [...lesson.trio.slice(1), lesson.trio[0]].map((l) =>
        l.toLowerCase(),
      ),
    });

    activities.push({
      ...base,
      id: ids[2],
      type: "trace",
      order: 3,
      instruction: `Trace a letra ${letter} com o dedo`,
      speech: `Trace a letra ${letterName}`,
      letter,
    });

    activities.push({
      ...base,
      id: ids[3],
      type: "listen",
      order: 4,
      instruction: "Qual palavra você ouviu?",
      speech: word.toLowerCase(),
      answer: word,
      options: place(
        option(word, true),
        lesson.listen.map((w) => option(w, false)),
        n + 1,
      ),
    });
  });
}

const course = {
  id: courseId,
  title: curriculum.courseTitle,
  description: curriculum.courseDescription,
  locale: "pt-BR",
  order: 1,
  moduleIds: modules.map((m) => m.id),
  lessonCount: lessons.length,
  published: true,
};

const write = (collection, file, data) => {
  mkdirSync(join(root, "seed", collection), { recursive: true });
  writeFileSync(
    join(root, "seed", collection, file),
    `${JSON.stringify(data, null, 2)}\n`,
  );
};

write("courses", "course_001.json", course);
write("modules", "modules.json", modules);
write("lessons", "lessons.json", lessons);
write("activities", "activities.json", activities);

console.log(
  `built ${modules.length} modules, ${lessons.length} lessons, ` +
    `${activities.length} activities from content/curriculum.json`,
);
