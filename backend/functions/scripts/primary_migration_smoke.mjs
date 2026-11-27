/**
 * Emulator-only rehearsal for the `primary` child migration (ADR 0024).
 *
 * Fixtures cover two families with a primary child, one family with only
 * orphan references, and one family with no references. The smoke exercises
 * inventory, dry-run, apply, idempotent re-apply, rollback and the preservation
 * of the legacy documents. It prints aggregate counts only.
 */
import assert from "node:assert/strict";

import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

import {
  inventoryPrimaryChildren,
  migratePrimaryChildren,
  rollbackPrimaryMigration,
} from "./primary_migration.mjs";

assert.match(
  process.env.FIRESTORE_EMULATOR_HOST ?? "",
  /^(localhost|127\.0\.0\.1):\d+$/,
  "FIRESTORE_EMULATOR_HOST must point to a local emulator",
);

const project = "demo-letrando";
initializeApp({ projectId: project });
const db = getFirestore();
const fixtures = ["family_a", "family_b", "family_c"];
const now = Timestamp.now();

async function countChildren(uid) {
  const snapshot = await db.collection(`users/${uid}/children`).get();
  return {
    total: snapshot.size,
    primary: snapshot.docs.filter((document) => document.id === "primary").length,
    migrated: snapshot.docs.filter((document) => document.id !== "primary").length,
  };
}

async function mapping(uid) {
  return db.doc(`users/${uid}/migrations/primaryChild`).get();
}

async function countMappings() {
  let count = 0;
  for (const uid of fixtures) {
    if ((await mapping(uid)).exists) count += 1;
  }
  return count;
}

async function seed() {
  for (const uid of fixtures) {
    await db.doc(`users/${uid}`).set({ displayName: `Synthetic ${uid.slice(-1)}` });
  }

  await db.doc("users/family_a/children/primary").set({
    name: "Criança A",
    age: 5,
    avatarId: "teal",
    learningLevel: "pre_literacy",
    currentCourseId: "course_001",
    currentLessonId: "lesson_001",
    createdAt: now,
    updatedAt: now,
  });
  await db.doc("users/family_a/children/primary/bookmarks/sapo").set({
    bookId: "sapo", contentVersion: 1, pageIndex: 0,
  });
  await db.doc("users/family_a/children/primary/dailySummaries/2026-11-27").set({
    lessonsCompleted: 1,
  });
  for (const sessionId of ["session_a1", "session_a2"]) {
    await db.doc(`users/family_a/sessions/${sessionId}`).set({
      childId: "primary",
      lessonId: "lesson_001",
      activityIds: ["a1", "a2", "a3", "a4"],
      contentVersion: 1,
      status: "active",
    });
    await db.doc(`users/family_a/activityAttempts/${sessionId}_req1`).set({
      childId: "primary",
      sessionId,
      lessonId: "lesson_001",
      activityId: "a1",
      requestId: "req1",
    });
  }
  await db.doc("users/family_a/learningProgress/primary_lesson_001").set({
    childId: "primary",
    lessonId: "lesson_001",
    status: "in_progress",
  });
  await db.doc("users/family_a/gamification/primary").set({
    childId: "primary", xp: 50, coins: 10, streak: 1,
  });
  await db.doc("users/family_a/assessmentResults/primary").set({
    childId: "primary", score: 1,
  });

  await db.doc("users/family_b/sessions/session_b1").set({
    childId: "primary", lessonId: "lesson_001", activityIds: ["b1"],
  });
  await db.doc("users/family_b/gamification/primary").set({
    childId: "primary", xp: 10,
  });

  await db.doc("users/family_c/children/primary").set({
    name: "Criança C", age: 6, avatarId: "orange", createdAt: now, updatedAt: now,
  });
}

try {
  await seed();

  const before = await inventoryPrimaryChildren(db);
  assert.equal(before.usersScanned, 3);
  assert.equal(before.primaryChildren, 2);
  assert.equal(before.usersWithPrimary, 2);
  assert.deepEqual(before.references, {
    sessions: 3,
    learningProgress: 1,
    activityAttempts: 2,
    gamification: 2,
    assessmentResults: 1,
    bookmarks: 1,
    dailySummaries: 1,
    childCreationRequests: 0,
  });
  assert.equal(before.orphanUsers, 1);
  assert.deepEqual(before.orphanReferences, {
    sessions: 1,
    learningProgress: 0,
    activityAttempts: 0,
    gamification: 1,
    assessmentResults: 0,
    bookmarks: 0,
    dailySummaries: 0,
    childCreationRequests: 0,
  });

  const dryRun = await migratePrimaryChildren(db, { apply: false });
  assert.equal(dryRun.mode, "dry-run");
  assert.equal(dryRun.plannedUsers, 2);
  assert.equal((await countMappings()), 0);
  assert.equal((await countChildren("family_a")).migrated, 0);
  assert.equal((await countChildren("family_c")).migrated, 0);

  const applied = await migratePrimaryChildren(db, { apply: true });
  assert.equal(applied.migratedUsers, 2);
  assert.equal(applied.copied.sessions, 2);
  assert.equal(applied.copied.activityAttempts, 2);
  assert.equal(applied.copied.learningProgress, 1);
  assert.equal(applied.copied.gamification, 1);
  assert.equal(applied.copied.assessmentResults, 1);
  assert.equal(applied.copied.bookmarks, 1);
  assert.equal(applied.copied.dailySummaries, 1);

  const familyA = await countChildren("family_a");
  const familyC = await countChildren("family_c");
  assert.equal(familyA.primary, 1);
  assert.equal(familyA.migrated, 1);
  assert.equal(familyC.primary, 1);
  assert.equal(familyC.migrated, 1);
  assert.equal(await countMappings(), 2);
  assert.equal((await mapping("family_b")).exists, false);

  const mapA = await mapping("family_a");
  const newChildA = mapA.get("newChildId");
  assert.equal(mapA.get("status"), "migrated");
  assert.equal(mapA.get("legacyId"), "primary");
  assert.equal(mapA.get("flowVersion"), "primary-migration-v1");
  assert.equal(
    (await db.doc(`users/family_a/children/${newChildA}`).get()).get("name"),
    "Criança A",
  );

  const migratedSessions = await db.collection("users/family_a/sessions").get();
  assert.equal(migratedSessions.docs.filter((document) =>
    document.get("childId") === newChildA,
  ).length, 2);
  assert.equal(migratedSessions.docs.filter((document) =>
    document.get("childId") === "primary",
  ).length, 2);
  const migratedAttempts = await db.collection("users/family_a/activityAttempts").get();
  assert.equal(migratedAttempts.docs.filter((document) =>
    document.get("childId") === newChildA,
  ).length, 2);
  assert.equal(
    (await db.doc(`users/family_a/gamification/${newChildA}`).get()).get("childId"),
    newChildA,
  );
  assert.equal(
    (await db.doc(`users/family_a/assessmentResults/${newChildA}`).get()).get("childId"),
    newChildA,
  );

  const repeated = await migratePrimaryChildren(db, { apply: true });
  assert.equal(repeated.alreadyMigratedUsers, 2);
  assert.equal(repeated.copied.sessions, 0);
  assert.equal(repeated.copied.activityAttempts, 0);
  assert.equal((await countChildren("family_a")).migrated, 1);
  assert.equal(await countMappings(), 2);

  const rolledBack = await rollbackPrimaryMigration(db);
  assert.equal(rolledBack.rolledBackUsers, 2);
  assert.equal(rolledBack.deleted.sessions, 2);
  assert.equal(rolledBack.deleted.activityAttempts, 2);
  assert.equal(rolledBack.deleted.learningProgress, 1);
  assert.equal(rolledBack.deleted.gamification, 1);
  assert.equal(rolledBack.deleted.assessmentResults, 1);
  assert.equal(rolledBack.deleted.bookmarks, 1);
  assert.equal(rolledBack.deleted.dailySummaries, 1);
  assert.equal(await countMappings(), 0);
  assert.equal((await countChildren("family_a")).migrated, 0);
  assert.equal((await countChildren("family_c")).migrated, 0);
  assert.equal((await countChildren("family_a")).primary, 1);
  assert.equal((await countChildren("family_c")).primary, 1);
  assert.equal((await db.doc("users/family_a/children/primary").get()).exists, true);
  assert.equal(
    (await db.collection("users/family_a/sessions").get()).docs.filter((document) =>
      document.get("childId") === "primary",
    ).length,
    2,
  );
  assert.equal((await inventoryPrimaryChildren(db)).totalReferences, before.totalReferences);

  console.log(JSON.stringify({
    fixture: "two families with primary, one orphan family, one primary-only family",
    before,
    dryRun: { plannedUsers: dryRun.plannedUsers, writes: 0 },
    applied: {
      migratedUsers: applied.migratedUsers,
      copied: applied.copied,
      primaryChildrenAfter: (await countChildren("family_a")).primary +
        (await countChildren("family_c")).primary,
      mappings: 2,
    },
    repeated: { alreadyMigratedUsers: repeated.alreadyMigratedUsers, copied: repeated.copied },
    rolledBack,
  }, null, 2));
  console.log("primary migration rehearsal passed");
} finally {
  for (const uid of fixtures) {
    await db.recursiveDelete(db.doc(`users/${uid}`));
  }
}
