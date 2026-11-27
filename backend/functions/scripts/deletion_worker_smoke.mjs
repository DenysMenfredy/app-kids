/**
 * Emulator-only check for the durable account-deletion worker (ADR 0023).
 *
 * Creates synthetic user data (including one Storage object), processes the
 * tombstone, and verifies explicit collections, Storage, Auth, the financial
 * subscription placeholder and the tombstone itself. Then it proves a late
 * entitlement/trial callback cannot recreate deleted state and that the sweep
 * resumes a `failed` job.
 */
import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";

import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

import { processDeletion, runDeletionSweep } from "../lib/account/deletion_worker.js";
import { claimTrialForCheckout } from "../lib/payments/trial_eligibility.js";
import { syncEntitlementForUser } from "../lib/subscriptions/sync_entitlement.js";

for (const key of ["FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST"]) {
  assert.match(
    process.env[key] ?? "",
    /^(localhost|127\.0\.0\.1):\d+$/,
    `${key} must point to a local emulator`,
  );
}
assert.match(
  process.env.STORAGE_EMULATOR_HOST ?? "",
  /^(https?:\/\/)?(localhost|127\.0\.0\.1):\d+$/,
  "STORAGE_EMULATOR_HOST must point to a local emulator",
);

const project = "demo-letrando";
const bucketName = process.env.STORAGE_BUCKET ?? "demo-letrando.appspot.com";
initializeApp({ projectId: project });
const auth = getAuth();
const db = getFirestore();
const bucket = getStorage().bucket(bucketName);
const users = [];

async function createSyntheticUser(label) {
  const password = randomBytes(24).toString("base64url");
  const user = await auth.createUser({
    email: `${label}-${randomBytes(6).toString("hex")}@example.test`,
    password,
    emailVerified: true,
  });
  users.push(user.uid);
  await db.doc(`users/${user.uid}`).set({
    displayName: "Responsável",
    locale: "pt-BR",
    onboardingState: "created",
    createdAt: Timestamp.now(),
  });
  return user.uid;
}

async function seedDeletionData(uid, status = "requested", attempts = 0) {
  await db.doc(`users/${uid}/children/child1`).set({
    name: "Criança", age: 5, avatarId: "teal",
  });
  await db.doc(`users/${uid}/children/child1/dailySummaries/2026-11-27`).set({
    lessonsCompleted: 1,
  });
  await db.doc(`users/${uid}/sessions/session1`).set({ childId: "child1" });
  await db.doc(`users/${uid}/devices/device1`).set({ token: "synthetic" });
  await db.doc(`users/${uid}/entitlements/premium`).set({ active: true });
  await db.doc(`users/${uid}/billing/trial`).set({ state: "consumed" });
  await db.doc(`users/${uid}/consent/current`).set({ textVersion: "d07-placeholder-v1" });
  await db.doc(`users/${uid}/subscriptions/sub_financial`).set({
    provider: "stripe",
    amountCents: 1990,
    status: "active",
  });
  await db.doc(`users/${uid}/deletion/current`).set({
    schemaVersion: 1,
    flowVersion: "t08b-placeholder-v1",
    status,
    requestId: `delete_${randomBytes(6).toString("hex")}`,
    uid,
    attempts,
    nextAttemptAt: Timestamp.fromMillis(Date.now() - 1),
    requestedAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });
  const file = bucket.file(`users/${uid}/avatar.txt`);
  await file.save("synthetic");
}

async function expectMissing(path) {
  assert.equal((await db.doc(path).get()).exists, false, `${path} should be deleted`);
}

async function cleanup(uid) {
  try {
    await auth.deleteUser(uid);
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
  }
  await db.recursiveDelete(db.doc(`users/${uid}`));
  await bucket.deleteFiles({ prefix: `users/${uid}/`, force: true });
}

try {
  const uid = await createSyntheticUser("worker");
  await seedDeletionData(uid);

  assert.equal(await processDeletion(uid), "completed");
  for (const path of [
    `users/${uid}`,
    `users/${uid}/children/child1`,
    `users/${uid}/children/child1/dailySummaries/2026-11-27`,
    `users/${uid}/sessions/session1`,
    `users/${uid}/devices/device1`,
    `users/${uid}/entitlements/premium`,
    `users/${uid}/billing/trial`,
    `users/${uid}/consent/current`,
  ]) {
    await expectMissing(path);
  }
  assert.equal((await db.doc(`users/${uid}/subscriptions/sub_financial`).get()).exists, true);
  const tombstone = await db.doc(`users/${uid}/deletion/current`).get();
  assert.equal(tombstone.get("status"), "completed");
  assert.ok(tombstone.get("completedAt"));
  assert.equal(tombstone.get("financialRetention"), "d07-financial-placeholder-v1");
  assert.ok(Number(tombstone.get("attempts")) >= 1);
  assert.equal(tombstone.get("workerClaim"), undefined);
  const [fileExists] = await bucket.file(`users/${uid}/avatar.txt`).exists();
  assert.equal(fileExists, false);
  await assert.rejects(auth.getUser(uid), { code: "auth/user-not-found" });
  assert.equal(await processDeletion(uid), "skipped");

  // A late payment callback must not recreate deleted state.
  await syncEntitlementForUser(uid);
  await expectMissing(`users/${uid}/entitlements/premium`);
  assert.deepEqual(
    await claimTrialForCheckout(db, uid),
    { status: "unavailable" },
  );
  await expectMissing(`users/${uid}/billing/trial`);

  // A failed job with a due timestamp is resumed by the same sweep.
  const retryUid = await createSyntheticUser("retry");
  await seedDeletionData(retryUid, "failed", 2);
  await runDeletionSweep(Date.now());
  const retryTombstone = await db.doc(`users/${retryUid}/deletion/current`).get();
  assert.equal(retryTombstone.get("status"), "completed");
  await expectMissing(`users/${retryUid}/children/child1`);

  console.log("account deletion worker: explicit collections, Storage, Auth, financial placeholder, tombstone, late-callback guard and failed retry passed");
} finally {
  for (const uid of users) {
    await cleanup(uid);
  }
}
