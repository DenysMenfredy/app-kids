/**
 * Emulator-only F2 isolation check: two synthetic families must not read or
 * write each other's data through Firestore Rules or callables.
 *
 * Run after seeding the curriculum:
 *   SMOKE_FUNCTIONS_HOST=127.0.0.1:5001 npm run test:isolation:smoke
 */
import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";

import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

for (const key of ["FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST"]) {
  assert.match(
    process.env[key] ?? "",
    /^(localhost|127\.0\.0\.1):\d+$/,
    `${key} must point to a local emulator`,
  );
}

const project = "demo-letrando";
const functionsHost = process.env.SMOKE_FUNCTIONS_HOST ?? "localhost:5001";
const functionRoot = `http://${functionsHost}/${project}/southamerica-east1`;
const firestoreRoot =
  `http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${project}/databases/(default)/documents`;

initializeApp({ projectId: project });
const auth = getAuth();
const db = getFirestore();
const users = [];
const failures = [];

function check(label, condition, detail = "") {
  if (condition) {
    console.log(`ok - ${label}${detail ? ` (${detail})` : ""}`);
  } else {
    failures.push(label);
    console.error(`not ok - ${label}${detail ? ` (${detail})` : ""}`);
  }
}

async function call(name, token, data) {
  const response = await fetch(`${functionRoot}/${name}`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ data }),
  });
  return response.json();
}

async function signIn(email, password) {
  const response = await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-api-key`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  const result = await response.json();
  assert.ok(result.idToken, "synthetic sign-in failed");
  return result.idToken;
}

async function createParent(label) {
  const password = randomBytes(24).toString("base64url");
  const user = await auth.createUser({
    email: `isolation-${label}-${randomBytes(6).toString("hex")}@example.test`,
    password,
    emailVerified: true,
  });
  users.push(user.uid);
  for (let attempt = 0; attempt < 60; attempt += 1) {
    if ((await db.doc(`users/${user.uid}`).get()).get("onboardingState")) break;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  const token = await signIn(user.email, password);
  assert.equal((await call("recordParentConsent", token, {
    textVersion: "d07-placeholder-v1",
    purposes: { notifications: false, marketing: false, analytics: false },
    origin: "parent_app",
  })).result?.ok, true, "consent setup failed");
  return { user, token, password };
}

async function createChild(parent, name) {
  const result = await call("createChildProfile", parent.token, {
    requestId: `isolation_${randomBytes(8).toString("hex")}`,
    profile: { name, age: 5, avatarId: "teal" },
  });
  assert.ok(result.result?.childId, "child setup failed");
  return result.result.childId;
}

async function restGet(path, token) {
  const headers = token ? { Authorization: `Bearer ${token}` } : {};
  const response = await fetch(`${firestoreRoot}/${path}`, { headers });
  return response.status;
}

async function restPatch(path, token, field, value) {
  const headers = token
    ? { Authorization: `Bearer ${token}`, "Content-Type": "application/json" }
    : { "Content-Type": "application/json" };
  const response = await fetch(
    `${firestoreRoot}/${path}?updateMask.fieldPaths=${field}`,
    {
      method: "PATCH",
      headers,
      body: JSON.stringify({ fields: { [field]: { stringValue: value } } }),
    },
  );
  return response.status;
}

function denied(result) {
  // completeLesson uses failed-precondition for an unknown session, which is
  // still a typed denial; no caller can distinguish another family by ID.
  return ["NOT_FOUND", "PERMISSION_DENIED", "FAILED_PRECONDITION"]
    .includes(result?.error?.status);
}

try {
  const familyA = await createParent("a");
  const familyB = await createParent("b");
  const childA = await createChild(familyA, "Criança A");
  const childB = await createChild(familyB, "Criança B");

  // Trusted synthetic state for read/write boundary checks.
  await db.doc(`users/${familyA.user.uid}/children/${childA}/bookmarks/sapo`).set({
    bookId: "sapo", contentVersion: 1, pageIndex: 0,
  });
  await db.doc(`users/${familyA.user.uid}/gamification/${childA}`).set({ xp: 50 });
  await db.doc(`users/${familyA.user.uid}/subscriptions/sub_a`).set({ status: "active" });
  await db.doc(`users/${familyA.user.uid}/entitlements/premium`).set({ active: true });
  await db.doc(`users/${familyA.user.uid}/notificationPreferences/default`).set({
    dailyReminder: true, achievement: true, weeklyReport: true,
    subscription: true, marketing: false, preferredTime: "18:00",
  });
  await db.doc(`users/${familyA.user.uid}/notifications/note_a`).set({ title: "A" });
  await db.doc(`users/${familyA.user.uid}/devices/device_a`).set({ token: "synthetic" });

  // A can learn in its own family; B must not be able to use A's IDs.
  assert.ok((await call("submitAssessment", familyA.token, {
    childId: childA,
    answers: {
      q_letters: "some", q_writes_name: "not_yet", q_reading_together: "rarely",
    },
  })).result);
  const started = await call("startLessonSession", familyA.token, {
    childId: childA, lessonId: "lesson_001", contentVersion: 1,
  });
  const sessionA = started.result?.sessionId;
  check("owner can create a lesson session", Boolean(sessionA));

  const ownReads = [
    `users/${familyA.user.uid}`,
    `users/${familyA.user.uid}/consent/current`,
    `users/${familyA.user.uid}/children/${childA}`,
    `users/${familyA.user.uid}/children/${childA}/bookmarks/sapo`,
    `users/${familyA.user.uid}/gamification/${childA}`,
    `users/${familyA.user.uid}/subscriptions/sub_a`,
    `users/${familyA.user.uid}/entitlements/premium`,
    `users/${familyA.user.uid}/notificationPreferences/default`,
    `users/${familyA.user.uid}/notifications/note_a`,
    `users/${familyA.user.uid}/devices/device_a`,
  ];
  for (const path of ownReads) {
    check(`owner reads ${path.split("/").slice(2).join("/") || "profile"}`,
      (await restGet(path, familyA.token)) === 200);
    check(`other family cannot read ${path.split("/").slice(2).join("/") || "profile"}`,
      (await restGet(path, familyB.token)) === 403);
  }
  check("anonymous cannot read a family profile",
    [401, 403].includes(await restGet(`users/${familyA.user.uid}`, null)));
  check("other family cannot read the second child",
    (await restGet(`users/${familyA.user.uid}/children/${childA}`, familyB.token)) === 403);
  check("owner cannot read the other family's child",
    (await restGet(`users/${familyB.user.uid}/children/${childB}`, familyA.token)) === 403);

  check("other family cannot update the owner's child",
    (await restPatch(`users/${familyA.user.uid}/children/${childA}`,
      familyB.token, "avatarId", "purple")) === 403);
  check("other family cannot update the owner's profile",
    (await restPatch(`users/${familyA.user.uid}`,
      familyB.token, "displayName", "Hijacked")) === 403);
  check("owner can update their own child",
    (await restPatch(`users/${familyA.user.uid}/children/${childA}`,
      familyA.token, "avatarId", "purple")) === 200);

  const cross = {
    saveBookBookmark: { childId: childA, bookId: "sapo", contentVersion: 1, pageIndex: 0 },
    submitAssessment: { childId: childA, answers: {
      q_letters: "some", q_writes_name: "not_yet", q_reading_together: "rarely",
    } },
    startLessonSession: { childId: childA, lessonId: "lesson_001", contentVersion: 1 },
    updateLessonSession: { childId: childA, sessionId: sessionA, action: "heartbeat", sequence: 1 },
    recoverLessonSession: { childId: childA, sessionId: sessionA, lessonId: "lesson_001" },
    getWeeklyLearningSummary: { childId: childA },
    completeLesson: { childId: childA, sessionId: sessionA, lessonId: "lesson_001" },
    submitActivityAttempt: { childId: childA, sessionId: sessionA,
      activityId: "activity_001", requestId: "isolation_cross", response: { selectedLabel: "A" } },
  };
  for (const [name, data] of Object.entries(cross)) {
    const result = await call(name, familyB.token, data);
    check(`other family is denied by ${name}`, denied(result),
      result?.error?.status ?? "NO_ERROR");
  }

  const ownSummary = await call("getWeeklyLearningSummary", familyB.token, { childId: childB });
  check("other family can still use its own child", Boolean(ownSummary.result));

  const switchedToken = await signIn(familyB.user.email, familyB.password);
  check("a fresh account switch token cannot read the old family",
    (await restGet(`users/${familyA.user.uid}/children/${childA}`, switchedToken)) === 403);
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

if (failures.length > 0) {
  console.error(`${failures.length} isolation check(s) failed.`);
  process.exit(1);
}
console.log("F2 isolation smoke passed for two synthetic families.");
