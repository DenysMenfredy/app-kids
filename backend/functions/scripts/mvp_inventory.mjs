/** F0 repository inventory; optional emulator count is read-only and contains no PII. */
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";

const root = new URL("../../../", import.meta.url);
const read = (path) => readFileSync(new URL(path, root), "utf8");
const json = (path) => JSON.parse(read(path));
const modules = json("backend/seed/modules/modules.json");
const lessons = json("backend/seed/lessons/lessons.json");
const activities = json("backend/seed/activities/activities.json");
const stories = json("backend/seed/stories/stories.json");
const books = json("backend/seed/books/books.json");
const bookContents = json("backend/seed/bookContents/bookContents.json");
assert.equal(modules.length, 7); assert.equal(lessons.length, 37);
assert.equal(stories.length, 6); assert.equal(books.length, 6);
assert.equal(bookContents.length, 6);
assert.equal(new Set(lessons.map((lesson) => lesson.id)).size, lessons.length);
const report = {
  scope: "repository plus optional local demo emulator, not remote project/console evidence",
  firebaseProjects: json("backend/.firebaserc").projects,
  region: "southamerica-east1", nativeId: "br.com.lele.lele",
  nativeConfigPresent: {
    android: existsSync(new URL("lele/android/app/google-services.json", root)),
    ios: existsSync(new URL("lele/ios/Runner/GoogleService-Info.plist", root)),
  },
  manifest: { modules: modules.length, lessons: lessons.length,
    coreActivities: activities.length, comprehensionStories: stories.length, books: books.length,
    bookPayloads: bookContents.length },
  billing: { channel: "native_stores_only", trialPromise: false,
    periods: ["monthly", "quarterly", "annual"],
    approvedStoreProductIds: [], remoteCustomerInventory: "not inspected; legacy reconciliation preserved" },
  legacyData: { remotePrimaryCount: "not inspected; staging migration not authorized by local evidence" },
};
if (process.argv.includes("--emulator")) {
  assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? "", /^(127\.0\.0\.1|localhost):\d+$/);
  const { initializeApp } = await import("firebase-admin/app");
  const { getFirestore } = await import("firebase-admin/firestore");
  const app = initializeApp({ projectId: "demo-letrando" });
  try {
    // Empty projection: no child name, avatar, birth data or progress is fetched.
    const children = await getFirestore().collectionGroup("children").select().get();
    report.legacyData.localDemoChildren = children.size;
    report.legacyData.localDemoPrimary = children.docs.filter((doc) => doc.id === "primary").length;
  } finally { await app.delete(); }
}
console.log(JSON.stringify(report, null, 2));
