/**
 * Emulator-only G1 placement check: without a current full-curriculum
 * entitlement, a high assessment band is capped to the free module and the
 * child can start its first lesson. Premium keeps the computed band.
 */
import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";

import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

for (const key of ["FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST"]) {
  assert.match(
    process.env[key] ?? "",
    /^(localhost|127\.0\.0\.1):\d+$/,
    `${key} must point to a local emulator`,
  );
}

const project = "demo-letrando";
const functionsHost = process.env.SMOKE_FUNCTIONS_HOST ?? "localhost:5001";
const root = `http://${functionsHost}/${project}/southamerica-east1`;
initializeApp({ projectId: project });
const auth = getAuth();
const db = getFirestore();
const users = [];

async function call(name, token, data) {
  const response = await fetch(`${root}/${name}`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ data }),
  });
  return response.json();
}

async function parent(label) {
  const password = randomBytes(24).toString("base64url");
  const user = await auth.createUser({
    email: `placement-${label}-${randomBytes(6).toString("hex")}@example.test`,
    password,
    emailVerified: true,
  });
  users.push(user.uid);
  for (let i = 0; i < 60; i += 1) {
    if ((await db.doc(`users/${user.uid}`).get()).get("onboardingState")) break;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  const login = await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-api-key`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: user.email, password, returnSecureToken: true }),
    },
  ).then((response) => response.json());
  assert.ok(login.idToken);
  assert.equal((await call("recordParentConsent", login.idToken, {
    textVersion: "d07-placeholder-v1",
    purposes: { notifications: false, marketing: false, analytics: false },
    origin: "parent_app",
  })).result?.ok, true);
  return { uid: user.uid, token: login.idToken };
}

async function child(owner) {
  const result = await call("createChildProfile", owner.token, {
    requestId: `placement_${randomBytes(8).toString("hex")}`,
    profile: { name: "Criança", age: 5, avatarId: "teal" },
  });
  assert.ok(result.result?.childId);
  return result.result.childId;
}

async function setEntitlement(uid, active, validUntil) {
  await db.doc(`users/${uid}/entitlements/premium`).set({
    active,
    features: ["full_curriculum"],
    validFrom: Timestamp.fromMillis(Date.now() - 60_000),
    validUntil: Timestamp.fromMillis(validUntil),
  });
}

const highScore = {
  q_letters: "most", q_writes_name: "alone", q_reading_together: "daily",
};

try {
  const free = await parent("free");
  const premium = await parent("premium");
  const expired = await parent("expired");
  const freeChild = await child(free);
  const premiumChild = await child(premium);
  const expiredChild = await child(expired);

  const freeResult = await call("submitAssessment", free.token, {
    childId: freeChild, answers: highScore,
  });
  assert.equal(freeResult.result?.freeTierCapped, true);
  assert.equal(freeResult.result?.requestedModuleNumber, 4);
  assert.equal(freeResult.result?.placement?.moduleNumber, 1);
  assert.equal(freeResult.result?.placement?.firstLessonId, "lesson_001");
  assert.equal(
    (await db.doc(`users/${free.uid}/children/${freeChild}`).get()).get("currentLessonId"),
    "lesson_001",
  );
  const freeStart = await call("startLessonSession", free.token, {
    childId: freeChild, lessonId: "lesson_001", contentVersion: 1,
  });
  assert.ok(freeStart.result?.sessionId, "free child must be able to start module 1");

  await setEntitlement(premium.uid, true, Date.now() + 60 * 60 * 1000);
  const premiumResult = await call("submitAssessment", premium.token, {
    childId: premiumChild, answers: highScore,
  });
  assert.equal(premiumResult.result?.freeTierCapped, false);
  assert.equal(premiumResult.result?.requestedModuleNumber, 4);
  assert.equal(premiumResult.result?.placement?.moduleNumber, 4);
  assert.equal(premiumResult.result?.placement?.firstLessonId, "lesson_014");
  const premiumStart = await call("startLessonSession", premium.token, {
    childId: premiumChild, lessonId: "lesson_014", contentVersion: 1,
  });
  assert.ok(premiumStart.result?.sessionId, "premium child must keep the computed band");

  await setEntitlement(expired.uid, true, Date.now() - 60_000);
  const expiredResult = await call("submitAssessment", expired.token, {
    childId: expiredChild, answers: highScore,
  });
  assert.equal(expiredResult.result?.freeTierCapped, true);
  assert.equal(expiredResult.result?.placement?.moduleNumber, 1);
  assert.equal(expiredResult.result?.requestedModuleNumber, 4);

  console.log("assessment placement: free → module 1, active Premium → original band, expired Premium → capped, no dead-end");
} finally {
  for (const uid of users) {
    try {
      await auth.deleteUser(uid);
    } catch (error) {
      if (error.code !== "auth/user-not-found") throw error;
    }
    await db.recursiveDelete(db.doc(`users/${uid}`));
  }
}
