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
import { getFirestore } from "firebase-admin/firestore";

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
  .map((entry) => entry.name);

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

let written = 0;
for (const collection of collections) {
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
          { ...document, updatedAt: new Date() },
          { merge: true },
        );
      }
      await batch.commit();
      written += chunk.length;
    }
    console.log(`seeded ${collection}/${file} — ${documents.length} document(s)`);
  }
}
console.log(`done — ${written} document(s) into ${projectId}`);
process.exit(0);
