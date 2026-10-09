/** Marks only the temporary smoke.sh account verified in the Auth emulator. */
import assert from "node:assert/strict";

import { getApp, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

assert.match(
  process.env.FIREBASE_AUTH_EMULATOR_HOST ?? "",
  /^(127\.0\.0\.1|localhost):\d+$/,
  "FIREBASE_AUTH_EMULATOR_HOST must point to a loopback emulator",
);

const uid = process.argv[2] ?? "";
assert.match(uid, /^[A-Za-z0-9_-]{8,128}$/, "Expected a Firebase emulator UID");

initializeApp({ projectId: "demo-letrando" });
try {
  const auth = getAuth();
  const user = await auth.getUser(uid);
  assert.match(
    user.email ?? "",
    /^smoke\+[A-Za-z0-9]+@example\.com$/,
    "Refusing to modify an account not created by backend/smoke.sh",
  );
  await auth.updateUser(uid, { emailVerified: true });
} finally {
  await getApp().delete();
}
