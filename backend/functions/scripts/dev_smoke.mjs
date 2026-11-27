/**
 * Smoke check against a deployed Letrando backend (dev or staging).
 *
 * Unlike backend/smoke.sh, this does not use emulators. It proves that the
 * deployed pieces work together: Application Default Credentials, the Auth
 * bootstrap trigger, the parent-consent gate, App Check enforcement, a real
 * callable round-trip and Firestore Admin access. It creates one synthetic
 * parent, verifies that child creation is blocked before consent, records
 * consent twice (idempotency), exercises createChildProfile twice with the
 * same requestId, verifies that a request without App Check is rejected, and
 * always removes the account and every document under it.
 *
 * Requirements:
 *   - Application Default Credentials for a principal allowed to manage
 *     Auth/Firestore and exchange App Check debug tokens in the project.
 *   - A debug token registered for the project's Android app in App Check:
 *       APP_CHECK_DEBUG_TOKEN=<token> npm run smoke:dev -- --project letrando-dev
 *
 * The web API key and Android app ID are public client config; they are read
 * from lele/config/firebase.<env>.json unless --web-api-key is passed.
 */
import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

import { CURRENT_CONSENT_TEXT_VERSION } from "../lib/domain/consent.js";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "../../..");
const projects = new Set(["letrando-dev", "letrando-staging"]);

function arg(name) {
  const index = process.argv.indexOf(`--${name}`);
  return index === -1 ? undefined : process.argv[index + 1];
}

const project = arg("project");
if (!project) {
  console.error("Missing --project <letrando-dev|letrando-staging>");
  process.exit(2);
}
// Hard stop: this script creates and deletes Auth users and Firestore data.
if (!projects.has(project)) {
  console.error(
    `Refusing to smoke-test ${project}; only ${[...projects].join(", ")} are allowed.`,
  );
  process.exit(2);
}

const environment = project.slice("letrando-".length);
const configPath = join(repoRoot, "lele", "config", `firebase.${environment}.json`);
let clientConfig;
try {
  clientConfig = JSON.parse(readFileSync(configPath, "utf8"));
} catch (error) {
  console.error(`Could not read the public client config at ${configPath}: ${error.message}`);
  process.exit(2);
}
const webApiKey = arg("web-api-key") ?? process.env.FIREBASE_WEB_API_KEY ??
  clientConfig.FIREBASE_ANDROID_API_KEY;
const androidAppId = clientConfig.FIREBASE_ANDROID_APP_ID;
if (!webApiKey || !androidAppId) {
  console.error(`${configPath} is missing FIREBASE_ANDROID_API_KEY or FIREBASE_ANDROID_APP_ID.`);
  process.exit(2);
}

const debugToken = process.env.APP_CHECK_DEBUG_TOKEN;
if (!debugToken) {
  console.error(
    "Missing APP_CHECK_DEBUG_TOKEN. Register a debug token for the project's Android app in " +
      "the App Check console, then export it for this command only.",
  );
  process.exit(2);
}

const evidencePath = arg("evidence");
const functionRoot = `https://southamerica-east1-${project}.cloudfunctions.net`;
const checks = [];
let status = "failed";
let failure = null;
let user = null;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function pass(name) {
  checks.push({ name, ok: true });
  console.log(`ok - ${name}`);
}

async function request(url, { headers = {}, body } = {}) {
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", ...headers },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(30_000),
  });
  const text = await response.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    // A proxy or an HTML error page; the status is still useful.
  }
  return { status: response.status, json };
}

async function accessToken(credential) {
  const token = await credential.getAccessToken();
  if (!token?.access_token) throw new Error("Application Default Credentials returned no access token.");
  return token.access_token;
}

async function exchangeDebugToken(accessTokenValue) {
  const url =
    `https://firebaseappcheck.googleapis.com/v1/projects/${project}/apps/` +
    `${encodeURIComponent(androidAppId)}:exchangeDebugToken`;
  const response = await request(url, {
    headers: { Authorization: `Bearer ${accessTokenValue}` },
    body: { debugToken },
  });
  if (!response.json?.token) {
    throw new Error(
      `App Check debug-token exchange failed (HTTP ${response.status}). ` +
        "Register the token for this Android app in the App Check console and retry.",
    );
  }
  return response.json.token;
}

async function waitForUserDocument(uid) {
  for (let attempt = 0; attempt < 60; attempt += 1) {
    if ((await db.doc(`users/${uid}`).get()).exists) return true;
    await sleep(500);
  }
  return false;
}

async function callCreateChildProfile(idToken, appCheckToken, data) {
  return request(`${functionRoot}/createChildProfile`, {
    headers: {
      Authorization: `Bearer ${idToken}`,
      ...(appCheckToken ? { "X-Firebase-AppCheck": appCheckToken } : {}),
    },
    body: { data },
  });
}

async function callRecordParentConsent(idToken, appCheckToken, data) {
  return request(`${functionRoot}/recordParentConsent`, {
    headers: {
      Authorization: `Bearer ${idToken}`,
      ...(appCheckToken ? { "X-Firebase-AppCheck": appCheckToken } : {}),
    },
    body: { data },
  });
}

let credential;
let app;
let auth;
let db;
try {
  credential = applicationDefault();
  app = initializeApp({ projectId: project, credential });
  auth = getAuth(app);
  db = getFirestore(app);
} catch (error) {
  console.error(
    `Could not initialize Firebase Admin for ${project}: ${error.message}\n` +
      "Run `gcloud auth application-default login` as a principal with access to the project, " +
      "or set GOOGLE_APPLICATION_CREDENTIALS to a deploy service account.",
  );
  process.exit(2);
}

try {
  const appCheckToken = await exchangeDebugToken(await accessToken(credential));
  pass("App Check debug token exchanged for a project token");

  const suffix = randomBytes(8).toString("hex");
  const password = randomBytes(24).toString("base64url");
  user = await auth.createUser({
    // Reserved test domain: no real inbox, no personal data.
    email: `smoke+${suffix}@example.test`,
    password,
    emailVerified: true,
  });
  pass("synthetic parent created in Auth");

  const bootstrapReady = await waitForUserDocument(user.uid);
  if (!bootstrapReady) {
    throw new Error("The onUserCreated trigger did not create users/{uid} within 30s.");
  }
  pass("onUserCreated bootstrap created the parent profile");

  const signIn = await request(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${encodeURIComponent(webApiKey)}`,
    { body: { email: user.email, password, returnSecureToken: true } },
  );
  if (!signIn.json?.idToken) {
    throw new Error(`Synthetic sign-in failed (HTTP ${signIn.status}).`);
  }
  const idToken = signIn.json.idToken;
  pass("synthetic parent signed in and received an ID token");

  const requestId = `smoke_${suffix}`;
  const data = {
    requestId,
    profile: { name: "Smoke", age: 5, avatarId: "teal" },
  };

  const beforeConsent = await callCreateChildProfile(idToken, appCheckToken, data);
  assert.equal(beforeConsent.json?.error?.status, "FAILED_PRECONDITION");
  assert.equal(beforeConsent.json?.error?.details?.code, "consent_required");
  pass("child creation is blocked before the parent records consent");

  const consent = {
    textVersion: CURRENT_CONSENT_TEXT_VERSION,
    purposes: { notifications: false, marketing: false, analytics: false },
    origin: "parent_app",
  };
  const recorded = await callRecordParentConsent(idToken, appCheckToken, consent);
  assert.equal(recorded.json?.result?.ok, true);
  assert.equal(recorded.json?.result?.changed, true);
  const replayed = await callRecordParentConsent(idToken, appCheckToken, consent);
  assert.equal(replayed.json?.result?.ok, true);
  assert.equal(replayed.json?.result?.changed, false);
  pass("parent consent is recorded idempotently");

  const first = await callCreateChildProfile(idToken, appCheckToken, data);
  const childId = first.json?.result?.childId;
  if (!childId) {
    throw new Error(
      `createChildProfile failed (HTTP ${first.status}, ` +
        `${first.json?.error?.status ?? "no error status"}).`,
    );
  }
  pass("createChildProfile succeeded with App Check and a verified parent");

  const second = await callCreateChildProfile(idToken, appCheckToken, data);
  assert.equal(second.json?.result?.childId, childId);
  pass("replaying the same requestId returned the same child and did not duplicate it");

  const child = await db.doc(`users/${user.uid}/children/${childId}`).get();
  assert.equal(child.exists, true);
  assert.equal(child.get("name"), "Smoke");
  const children = await db.collection(`users/${user.uid}/children`).get();
  assert.equal(children.size, 1);
  pass("the child document is stored once under the synthetic parent");

  const denied = await callCreateChildProfile(idToken, null, {
    requestId: `smoke_denied_${suffix}`,
    profile: { name: "Smoke", age: 5, avatarId: "teal" },
  });
  assert.equal(denied.status, 401);
  assert.equal(denied.json?.error?.status, "UNAUTHENTICATED");
  pass("a callable request without App Check is rejected");

  status = "passed";
} catch (error) {
  failure = error;
  console.error(`FAILED: ${error.message}`);
  process.exitCode = 1;
} finally {
  let cleanupOk = true;
  if (user) {
    try {
      assert.match(user.email ?? "", /^smoke\+[a-f0-9]+@example\.test$/);
      await auth.deleteUser(user.uid);
      await db.recursiveDelete(db.doc(`users/${user.uid}`));
      pass("synthetic account and its Firestore data removed");
    } catch (error) {
      cleanupOk = false;
      console.error(`Cleanup failed for the synthetic account: ${error.message}`);
      process.exitCode = 1;
    }
  }

  if (evidencePath) {
    mkdirSync(dirname(evidencePath), { recursive: true });
    writeFileSync(
      evidencePath,
      `${JSON.stringify(
        {
          project,
          checkedAt: new Date().toISOString(),
          status: cleanupOk ? status : "failed",
          checks,
          error: failure?.message ?? null,
        },
        null,
        2,
      )}\n`,
    );
  }

  await app.delete();
}
