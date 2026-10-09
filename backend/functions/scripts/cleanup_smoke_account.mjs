/** Removes only the temporary parent account created by backend/smoke.sh. */
import assert from "node:assert/strict";

import { getApp, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

for (const [name, value] of [
  ["FIRESTORE_EMULATOR_HOST", process.env.FIRESTORE_EMULATOR_HOST],
  ["FIREBASE_AUTH_EMULATOR_HOST", process.env.FIREBASE_AUTH_EMULATOR_HOST],
]) {
  assert.match(value ?? "", /^(127\.0\.0\.1|localhost):\d+$/, `${name} must be a loopback emulator`);
}

const uid = process.argv[2] ?? "";
assert.match(uid, /^[A-Za-z0-9_-]{8,128}$/, "Expected a Firebase emulator UID");

initializeApp({ projectId: "demo-letrando" });
const db = getFirestore();
const auth = getAuth();

try {
  const userRef = db.doc(`users/${uid}`);
  let user;
  try {
    user = await auth.getUser(uid);
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
  }

  if (user) {
    assert.match(
      user.email ?? "",
      /^smoke\+[A-Za-z0-9]+@example\.com$/,
      "Refusing to remove an account not created by backend/smoke.sh",
    );
    await db.recursiveDelete(userRef);
    await auth.deleteUser(uid);
    console.log("Removed the temporary smoke-test parent and Firestore data.");
  } else {
    console.log("Smoke-test Auth account already absent; no Firestore data modified.");
  }
} finally {
  await getApp().delete();
}
