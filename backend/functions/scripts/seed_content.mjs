/**
 * Seeds educational content into Firestore from `backend/seed/`.
 *
 * Content is configuration-driven (spec §5), so the assessment questions,
 * option weights and placement bands live in the database rather than in
 * app or function code. This script is the dev/staging import path; in
 * production, content changes go through the manageContent callable.
 *
 * Usage (from backend/functions):
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 npm run seed -- --project letrando-dev
 *   GOOGLE_APPLICATION_CREDENTIALS=key.json npm run seed -- --project letrando-dev
 */
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { cert, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { bookPublicationProblem } from "../lib/domain/books.js";
import { lessonPublicationProblem } from "../lib/domain/lesson_content.js";

const seedRoot = join(dirname(fileURLToPath(import.meta.url)), "../../seed");

function arg(name) {
  const index = process.argv.indexOf(`--${name}`);
  return index === -1 ? undefined : process.argv[index + 1];
}

const projectId = arg("project");
if (!projectId) {
  console.error("Missing --project <projectId>");
  process.exit(1);
}
// Spec §21: production data is never touched from a development machine.
if (projectId.includes("production") && arg("force") === undefined) {
  console.error(
    "Refusing to seed a production project. Publish content through " +
      "manageContent instead, or pass --force <reason> deliberately.",
  );
  process.exit(1);
}

const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
initializeApp({
  projectId,
  ...(credentialsPath && !process.env.FIRESTORE_EMULATOR_HOST
    ? { credential: cert(JSON.parse(readFileSync(credentialsPath, "utf8"))) }
    : {}),
});
const db = getFirestore();

/** Each subdirectory of seed/ is a Firestore collection. */
const collections = readdirSync(seedRoot, { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .filter((name) => !arg("only") || arg("only").split(",").includes(name));

if (collections.includes("books") !== collections.includes("bookContents")) {
  throw new Error("Seed books and bookContents together.");
}

/**
 * A seed file holds either one document or an array of them — collections
 * like `activities` have hundreds, which would be unreadable one file each.
 */
function documentsIn(collection, file) {
  const parsed = JSON.parse(readFileSync(join(seedRoot, collection, file), "utf8"));
  const documents = Array.isArray(parsed) ? parsed : [parsed];
  return documents.map((document, index) => {
    const id = document.id ?? (Array.isArray(parsed) ? null : file.replace(/\.json$/, ""));
    if (!id) {
      throw new Error(`${collection}/${file}: document ${index} has no "id"`);
    }
    return [id, document];
  });
}

const books = collections.includes("books")
  ? documentsIn("books", "books.json") : [];
const bookContents = collections.includes("bookContents")
  ? new Map(documentsIn("bookContents", "bookContents.json")) : new Map();
// Validate the complete catalog before any Firestore writes.
for (const [id, book] of books) {
  const problem = bookPublicationProblem(id, book, bookContents.get(id) ?? {});
  if (problem) throw new Error(`${id}: ${problem}`);
}
if (books.length !== bookContents.size) throw new Error("Orphaned book content.");

function allDocuments(collection) {
  return readdirSync(join(seedRoot, collection)).filter((file) => file.endsWith(".json"))
    .flatMap((file) => documentsIn(collection, file).map(([, document]) => document));
}
if (collections.some((name) => ["lessons", "activities", "stories"].includes(name))) {
  if (!["lessons", "activities", "stories"].every((name) => collections.includes(name))) {
    throw new Error("Seed lessons, activities and stories together.");
  }
  const activityMap = new Map(allDocuments("activities").map((activity) => [activity.id, activity]));
  const storyMap = new Map(allDocuments("stories").map((story) => [story.id, story]));
  for (const lesson of allDocuments("lessons")) {
    const activities = lesson.activityIds.map((id) => activityMap.get(id));
    if (activities.some((activity) => !activity)) throw new Error(`${lesson.id}: missing activity`);
    const story = storyMap.get(activities[4]?.storyId) ?? null;
    const problem = lessonPublicationProblem(lesson.id, { lesson, activities, story });
    if (problem) throw new Error(`${lesson.id}: ${problem}`);
  }
}

let written = 0;
for (const collection of collections) {
  if (collection === "books" || collection === "bookContents") continue;
  for (const file of readdirSync(join(seedRoot, collection)).filter((f) =>
    f.endsWith(".json"),
  )) {
    const documents = documentsIn(collection, file);
    // Firestore caps a batch at 500 writes.
    for (let start = 0; start < documents.length; start += 400) {
      const chunk = documents.slice(start, start + 400);
      const batch = db.batch();
      for (const [id, document] of chunk) {
        batch.set(
          db.collection(collection).doc(id),
          { ...document, updatedAt: FieldValue.serverTimestamp() },
          { merge: !["lessons", "activities", "stories"].includes(collection) },
        );
      }
      await batch.commit();
      written += chunk.length;
    }
    console.log(`seeded ${collection}/${file} — ${documents.length} document(s)`);
  }
}
// Publish each catalog entry and its pages in the same atomic batch.
for (let start = 0; start < books.length; start += 200) {
  const batch = db.batch();
  for (const [id, book] of books.slice(start, start + 200)) {
    batch.set(db.collection("books").doc(id), { ...book, updatedAt: FieldValue.serverTimestamp() });
    batch.set(db.collection("bookContents").doc(id), {
      ...bookContents.get(id), updatedAt: FieldValue.serverTimestamp(),
    });
    written += 2;
  }
  await batch.commit();
}
if (books.length > 0) console.log(`seeded ${books.length} books with complete pages`);
console.log(`done — ${written} document(s) into ${projectId}`);
process.exit(0);
