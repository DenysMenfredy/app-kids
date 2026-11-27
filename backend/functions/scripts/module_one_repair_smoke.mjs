/**
 * Emulator-only rehearsal for the module-1 pointer repair (ADR 0025).
 *
 * Fixtures: three children above module 1 without access (module 2/3), one
 * entitled child, one already-free child and one unknown lesson. The smoke
 * checks dry-run, pointer-only apply, idempotent re-apply, preserved progress
 * and rollback counts.
 */
import assert from "node:assert/strict";

import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

import {
  inventoryModuleOneRepairs,
  repairModuleOnePlacements,
  rollbackModuleOneRepairs,
} from "./module_one_repair.mjs";

assert.match(
  process.env.FIRESTORE_EMULATOR_HOST ?? "",
  /^(localhost|127\.0\.0\.1):\d+$/,
  "FIRESTORE_EMULATOR_HOST must point to a local emulator",
);

const project = "demo-letrando";
initializeApp({ projectId: project });
const db = getFirestore();
const users = ["repair_a", "repair_b", "repair_c", "repair_d", "repair_e", "repair_f"];
const now = Timestamp.now();

async function child(uid, lessonId, learningLevel = "visual_recognition") {
  await db.doc(`users/${uid}`).set({ displayName: "Synthetic" });
  await db.doc(`users/${uid}/children/child`).set({
    name: "Criança",
    age: 5,
    avatarId: "teal",
    learningLevel,
    currentCourseId: "course_001",
    currentLessonId: lessonId,
    createdAt: now,
    updatedAt: now,
  });
}

async function entitlement(uid, validUntil) {
  await db.doc(`users/${uid}/entitlements/premium`).set({
    active: true,
    features: ["full_curriculum"],
    validFrom: Timestamp.fromMillis(Date.now() - 60_000),
    validUntil: Timestamp.fromMillis(validUntil),
  });
}

async function repairDocs() {
  let count = 0;
  for (const uid of users) {
    if ((await db.doc(`users/${uid}/migrations/moduleOneRepair`).get()).exists) {
      count += 1;
    }
  }
  return count;
}

async function pointer(uid) {
  return db.doc(`users/${uid}/children/child`).get();
}

try {
  await child("repair_a", "lesson_004");
  await child("repair_b", "lesson_004");
  await child("repair_c", "lesson_001", "pre_literacy");
  await child("repair_d", "lesson_008", "phonological");
  await child("repair_e", "lesson_does_not_exist");
  await child("repair_f", "lesson_004");

  await entitlement("repair_b", Date.now() + 60 * 60 * 1000);
  await entitlement("repair_d", Date.now() - 60_000);

  await db.doc("users/repair_a/learningProgress/child_lesson_004").set({
    childId: "child", lessonId: "lesson_004", status: "in_progress",
  });
  await db.doc("users/repair_a/sessions/old_session").set({
    childId: "child", lessonId: "lesson_004", status: "active",
  });
  await db.doc("users/repair_a/gamification/child").set({
    childId: "child", xp: 50, coins: 10,
  });
  await db.doc("users/repair_a/assessmentResults/child").set({
    childId: "child", score: 6,
  });

  const before = await inventoryModuleOneRepairs(db);
  assert.equal(before.usersScanned, 6);
  assert.equal(before.childrenScanned, 6);
  assert.equal(before.candidates, 3);
  assert.equal(before.entitled, 1);
  assert.equal(before.unknown, 1);
  assert.deepEqual(before.byModule, { 2: 3, 3: 1 });
  assert.equal(before.freeLessonId, "lesson_001");

  const dryRun = await repairModuleOnePlacements(db, { apply: false });
  assert.equal(dryRun.mode, "dry-run");
  assert.equal(dryRun.repaired, 0);
  assert.equal(await repairDocs(), 0);
  assert.equal((await pointer("repair_a")).get("currentLessonId"), "lesson_004");

  const applied = await repairModuleOnePlacements(db, { apply: true });
  assert.equal(applied.candidates, 3);
  assert.equal(applied.repaired, 3);
  assert.equal(await repairDocs(), 3);

  for (const uid of ["repair_a", "repair_d", "repair_f"]) {
    const repaired = await pointer(uid);
    assert.equal(repaired.get("currentLessonId"), "lesson_001");
    assert.equal(repaired.get("currentCourseId"), "course_001");
  }
  assert.equal((await pointer("repair_a")).get("learningLevel"), "visual_recognition");
  assert.equal((await pointer("repair_b")).get("currentLessonId"), "lesson_004");
  assert.equal((await pointer("repair_c")).get("currentLessonId"), "lesson_001");
  assert.equal((await pointer("repair_e")).get("currentLessonId"), "lesson_does_not_exist");

  assert.equal((await db.doc("users/repair_a/learningProgress/child_lesson_004").get()).exists, true);
  assert.equal((await db.doc("users/repair_a/sessions/old_session").get()).exists, true);
  assert.equal((await db.doc("users/repair_a/gamification/child").get()).get("xp"), 50);
  assert.equal((await db.doc("users/repair_a/assessmentResults/child").get()).get("score"), 6);
  const repairA = await db.doc("users/repair_a/migrations/moduleOneRepair").get();
  assert.equal(repairA.get("flowVersion"), "module-one-repair-v1");
  assert.equal(
    repairA.get("children")?.child?.previousLessonId,
    "lesson_004",
  );

  const after = await inventoryModuleOneRepairs(db);
  assert.equal(after.candidates, 0);
  assert.equal(after.entitled, 1);
  assert.equal(after.unknown, 1);
  assert.equal(after.childrenScanned, 6);

  const repeated = await repairModuleOnePlacements(db, { apply: true });
  assert.equal(repeated.candidates, 0);
  assert.equal(repeated.repaired, 0);
  assert.equal(await repairDocs(), 3);

  const rolledBack = await rollbackModuleOneRepairs(db);
  assert.equal(rolledBack.repairDocuments, 3);
  assert.equal(rolledBack.restored, 3);
  assert.equal(await repairDocs(), 0);
  assert.equal((await pointer("repair_a")).get("currentLessonId"), "lesson_004");
  assert.equal((await pointer("repair_d")).get("currentLessonId"), "lesson_008");
  assert.equal((await pointer("repair_f")).get("currentLessonId"), "lesson_004");
  assert.equal((await db.doc("users/repair_a/learningProgress/child_lesson_004").get()).exists, true);
  const restored = await inventoryModuleOneRepairs(db);
  assert.equal(restored.candidates, 3);

  console.log(JSON.stringify({ before, dryRun, applied, after, repeated, rolledBack }, null, 2));
  console.log("module-1 repair rehearsal passed");
} finally {
  for (const uid of users) {
    await db.recursiveDelete(db.doc(`users/${uid}`));
  }
}
