/** Emulator-only regression. Real transactions/callables; FCM transport is simulated. */
import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { createRequire } from "node:module";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

for (const key of ["FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST"]) {
  assert.match(process.env[key] ?? "", /^(127\.0\.0\.1|localhost):\d+$/);
}
const app = initializeApp({ projectId: "demo-letrando" });
const db = getFirestore();
const auth = getAuth();
const messaging = getMessaging();
const original = messaging.sendEachForMulticast;
let mode = "ok";
let messages = [];
messaging.sendEachForMulticast = async (message) => {
  messages.push(message);
  if (mode === "throw") throw new Error("Simulated FCM outage");
  const responses = message.tokens.map((token) => ({
    success: !(mode === "mixed" && token.endsWith("retry")) && !token.endsWith("invalid"),
    ...(token.endsWith("invalid") ? { error: { code: "messaging/registration-token-not-registered" } } :
      mode === "mixed" && token.endsWith("retry") ? { error: { code: "messaging/internal-error" } } : {}),
  }));
  return { responses, successCount: responses.filter((r) => r.success).length,
    failureCount: responses.filter((r) => !r.success).length };
};
const require = createRequire(import.meta.url);
const { sendNotificationToUser } = require("../lib/notifications/send_notification.js");
const { tokenHash } = require("../lib/notifications/device_registration.js");
const users = [];
const installations = [];
const tokens = new Set();
const run = randomBytes(8).toString("hex");
const payload = { type: "daily_reminder", title: "Synthetic local test", body: "No real push" };
let checks = 0;
async function check(name, fn) { await fn(); checks++; console.log(`PASS ${name}`); }
async function parent() {
  const password = randomBytes(24).toString("base64url");
  const user = await auth.createUser({ email: `notify-${randomBytes(8).toString("hex")}@example.test`, password, emailVerified: true });
  users.push(user.uid);
  let bootstrapped = false;
  for (let attempt = 0; attempt < 100; attempt++) {
    if ((await db.doc(`users/${user.uid}`).get()).get("onboardingState")) { bootstrapped = true; break; }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  assert.ok(bootstrapped, "Auth bootstrap not ready");
  const result = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-api-key`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email: user.email, password, returnSecureToken: true }),
  }).then((r) => r.json());
  assert.ok(result.idToken);
  return { uid: user.uid, token: result.idToken };
}
async function call(name, owner, data) {
  return fetch(`http://127.0.0.1:5001/demo-letrando/southamerica-east1/${name}`, {
    method: "POST", headers: { "Content-Type": "application/json",
      ...(owner ? { Authorization: `Bearer ${owner.token}` } : {}) }, body: JSON.stringify({ data }),
  }).then((r) => r.json());
}
function installation(label) {
  const value = { deviceId: randomBytes(16).toString("hex"), installationSecret: randomBytes(32).toString("hex"),
    fcmToken: `synthetic_${run}_${label}`, platform: "android", permission: "authorized", notificationsEnabled: true };
  installations.push(value);
  tokens.add(value.fcmToken);
  return value;
}
async function register(owner, value) {
  assert.equal((await call("registerDevice", owner, value)).result?.ok, true);
}
async function reset(owner) {
  for (const doc of (await db.collection(`users/${owner.uid}/devices`).get()).docs) await doc.ref.delete();
  await db.doc(`users/${owner.uid}/notificationPreferences/default`).update({ dailyReminder: true });
  messages = []; mode = "ok";
}
const device = (owner, value) => db.doc(`users/${owner.uid}/devices/${value.deviceId}`);
try {
  const a = await parent(), b = await parent();
  const shared = installation("shared");
  await check("registration requires authentication", async () => {
    assert.equal((await call("registerDevice", null, shared)).error?.status, "UNAUTHENTICATED");
  });
  await check("registration validates platform, token and installation proof", async () => {
    for (const change of [{ platform: "toaster" }, { fcmToken: "" }, { deviceId: "../bad" },
      { installationSecret: "short" }, { permission: "unknown" }, { notificationsEnabled: "yes" }]) {
      assert.equal((await call("registerDevice", a, { ...shared, ...change })).error?.status, "INVALID_ARGUMENT");
    }
  });
  await check("submitted UID cannot redirect registration", async () => {
    await register(a, { ...shared, uid: b.uid });
    assert.ok((await device(a, shared).get()).exists);
    assert.equal((await device(b, shared).get()).exists, false);
  });
  await check("proof prevents hijacking and token duplication", async () => {
    assert.equal((await call("registerDevice", b, { ...shared, installationSecret: "f".repeat(64) })).error?.status, "PERMISSION_DENIED");
    const other = installation("duplicate");
    assert.equal((await call("registerDevice", b, { ...other, fcmToken: shared.fcmToken })).error?.status, "FAILED_PRECONDITION");
  });
  await check("account switch removes old owner; late logout cannot detach new owner", async () => {
    await register(b, shared);
    assert.equal((await device(a, shared).get()).exists, false);
    assert.equal((await call("unregisterDevice", a, shared)).result?.ok, true);
    assert.ok((await device(b, shared).get()).exists);
  });
  await check("owner logout detaches installation", async () => {
    assert.equal((await call("unregisterDevice", b, shared)).result?.ok, true);
    assert.equal((await device(b, shared).get()).exists, false);
  });
  await check("concurrent duplicate claims produce one external send", async () => {
    await reset(a); await register(a, installation("concurrent"));
    const results = await Promise.all([sendNotificationToUser(a.uid, payload, `${run}_same`), sendNotificationToUser(a.uid, payload, `${run}_same`)]);
    assert.equal(results.filter(Boolean).length, 1); assert.equal(messages.length, 1);
    const saved = await db.doc(`users/${a.uid}/notifications/${run}_same`).get();
    assert.equal(saved.get("status"), "accepted");
    assert.ok(saved.get("acceptedAt") instanceof Timestamp);
    assert.equal(saved.get("sentAt"), undefined);
  });
  await check("no-device failure remains retryable after registration", async () => {
    await reset(a); const key = `${run}_later`;
    assert.equal(await sendNotificationToUser(a.uid, payload, key), false);
    await register(a, installation("later"));
    assert.equal(await sendNotificationToUser(a.uid, payload, key), true);
  });
  await check("transient transport failure remains retryable", async () => {
    await reset(a); await register(a, installation("outage")); const key = `${run}_outage`;
    mode = "throw";
    await assert.rejects(sendNotificationToUser(a.uid, payload, key), /Simulated FCM outage/);
    mode = "ok";
    assert.equal(await sendNotificationToUser(a.uid, payload, key), true);
  });
  await check("current category opt-out suppresses external send", async () => {
    await reset(a); await register(a, installation("optout"));
    await db.doc(`users/${a.uid}/notificationPreferences/default`).update({ dailyReminder: false });
    assert.equal(await sendNotificationToUser(a.uid, payload, `${run}_optout`), false);
    assert.equal(messages.length, 0);
  });
  await check("partial retry only targets failed recipients; invalid token is cleaned", async () => {
    await reset(a);
    const invalid = installation("invalid");
    await register(a, invalid); await register(a, installation("valid")); await register(a, installation("retry"));
    mode = "mixed"; const key = `${run}_partial`;
    assert.equal(await sendNotificationToUser(a.uid, payload, key), true);
    assert.equal((await device(a, invalid).get()).exists, false);
    mode = "ok";
    assert.equal(await sendNotificationToUser(a.uid, payload, key), true);
    assert.equal(messages[1].tokens.length, 1);
    assert.ok(messages[1].tokens[0].endsWith("retry"));
    assert.equal(messages[0].data.notificationId, messages[1].data.notificationId);
  });
  console.log(`${checks} notification regressions passed. FCM was simulated; no real remote push sent.`);
} finally {
  messaging.sendEachForMulticast = original;
  for (const uid of users) { await db.recursiveDelete(db.doc(`users/${uid}`)); await auth.deleteUser(uid); }
  for (const value of installations) await db.doc(`notificationInstallations/${value.deviceId}`).delete();
  for (const token of tokens) await db.doc(`notificationTokens/${tokenHash(token)}`).delete();
  await app.delete();
}
