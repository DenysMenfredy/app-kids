/** Emulator-only integration check: publication, protected pages and bookmarks. */
import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { readFileSync } from "node:fs";

import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

for (const key of ["FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST"]) {
  assert.match(process.env[key] ?? "", /^(127\.0\.0\.1|localhost):\d+$/, `${key} must point to a local emulator`);
}
const project = "demo-letrando";
initializeApp({ projectId: project });
const db = getFirestore();
const auth = getAuth();
const functionRoot = `http://127.0.0.1:5001/${project}/southamerica-east1`;
const users = [];
const bookId = `book_smoke_${randomBytes(6).toString("hex")}`;

async function tokenFor(user, password) {
  const response = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-api-key`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email: user.email, password, returnSecureToken: true }),
  });
  const result = await response.json();
  assert.ok(result.idToken, "Auth emulator sign-in failed");
  return result.idToken;
}

async function createParent() {
  const password = randomBytes(24).toString("base64url");
  const user = await auth.createUser({
    email: `book-smoke-${randomBytes(6).toString("hex")}@example.test`,
    password, emailVerified: true,
  });
  users.push(user.uid);
  // Wait for bootstrap before changing roles or cleaning up this test account.
  for (let attempt = 0; attempt < 50; attempt++) {
    if ((await db.doc(`users/${user.uid}`).get()).get("onboardingState")) {
      return { user, password, token: await tokenFor(user, password) };
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("Auth bootstrap did not finish");
}

async function call(name, token, data) {
  const response = await fetch(`${functionRoot}/${name}`, {
    method: "POST", headers: { "Authorization": `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ data }),
  });
  return response.json();
}

async function readPages(token, id) {
  return fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${project}/databases/(default)/documents/bookContents/${id}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
}

try {
  const parent = await createParent();
  const stranger = await createParent();
  const created = await call("createChildProfile", parent.token, {
    requestId: `books_${randomBytes(6).toString("hex")}`,
    profile: { name: "Leitor", age: 5, avatarId: "teal" },
  });
  const childId = created.result?.childId;
  assert.ok(childId, "Server-created child profile missing");
  const bookmarkPath = `users/${parent.user.uid}/children/${childId}/bookmarks/sapo`;
  const data = { childId, bookId: "sapo", contentVersion: 1, pageIndex: 2 };
  assert.equal((await call("saveBookBookmark", parent.token, data)).result?.ok, true);
  assert.equal((await call("saveBookBookmark", parent.token, data)).result?.ok, true);
  const bookmark = await db.doc(bookmarkPath).get();
  assert.equal(bookmark.get("pageIndex"), 2);
  assert.ok(bookmark.get("updatedAt") instanceof Timestamp);
  assert.equal((await db.collection(`users/${parent.user.uid}/children/${childId}/bookmarks`).get()).size, 1);
  assert.equal((await db.collection(`users/${parent.user.uid}/gamification`).get()).size, 0);
  assert.equal((await call("saveBookBookmark", stranger.token, data)).error?.status, "NOT_FOUND");
  for (const [change, status] of [
    [{ pageIndex: -1 }, "INVALID_ARGUMENT"], [{ pageIndex: 999 }, "FAILED_PRECONDITION"],
    [{ contentVersion: 999 }, "FAILED_PRECONDITION"], [{ bookId: "trem" }, "PERMISSION_DENIED"],
  ]) assert.equal((await call("saveBookBookmark", parent.token, { ...data, ...change })).error?.status, status);
  assert.equal((await readPages(parent.token, "sapo")).status, 200);
  assert.equal((await readPages(parent.token, "trem")).status, 403);
  const entitlementRef = db.doc(`users/${parent.user.uid}/entitlements/premium`);
  await entitlementRef.set({ active: true, features: ["premium_books"],
    validFrom: Timestamp.fromMillis(Date.now() - 1000), validUntil: Timestamp.fromMillis(Date.now() + 60_000) });
  assert.equal((await readPages(parent.token, "trem")).status, 200);
  assert.equal((await call("saveBookBookmark", parent.token, { ...data, bookId: "trem" })).result?.ok, true);
  await entitlementRef.update({ active: false });
  assert.equal((await readPages(parent.token, "trem")).status, 403);
  assert.equal((await call("saveBookBookmark", parent.token, { ...data, bookId: "trem" })).error?.status, "PERMISSION_DENIED");
  console.log("Book reads/bookmarks: ownership, bounds, retries, server timestamps and Premium revocation passed.");

  assert.equal((await call("manageContent", parent.token, {
    collection: "books", docId: bookId, action: "publish",
  })).error?.status, "PERMISSION_DENIED");
  await auth.setCustomUserClaims(parent.user.uid, { role: "content_editor" });
  const editorToken = await tokenFor(parent.user, parent.password);
  const metadata = JSON.parse(readFileSync(new URL("../../seed/books/books.json", import.meta.url)))[0];
  const pages = JSON.parse(readFileSync(new URL("../../seed/bookContents/bookContents.json", import.meta.url)))[0];
  for (const [collection, content] of [
    ["books", { ...metadata, id: bookId }],
    ["bookContents", { ...pages, id: bookId, contentVersion: 999 }],
  ]) assert.equal((await call("manageContent", editorToken, { collection, docId: bookId, action: "upsert", content })).result?.ok, true);
  assert.equal((await call("manageContent", editorToken, { collection: "books", docId: bookId, action: "publish" })).error?.status, "FAILED_PRECONDITION");
  assert.equal((await db.doc(`books/${bookId}`).get()).get("published"), false);
  await call("manageContent", editorToken, { collection: "bookContents", docId: bookId, action: "upsert", content: { ...pages, id: bookId } });
  assert.equal((await call("manageContent", editorToken, { collection: "books", docId: bookId, action: "publish" })).result?.ok, true);
  assert.equal((await db.doc(`bookContents/${bookId}`).get()).get("published"), true);
  assert.equal((await readPages(parent.token, bookId)).status, 200);
  assert.equal((await call("manageContent", editorToken, { collection: "books", docId: bookId, action: "unpublish" })).result?.ok, true);
  assert.equal((await readPages(parent.token, bookId)).status, 403);
  console.log("Book publication: editor authorization, version validation and atomic publication/unpublication passed.");
} finally {
  await Promise.all([db.doc(`books/${bookId}`).delete(), db.doc(`bookContents/${bookId}`).delete()]);
  // Only fixtures created by this invocation are removed.
  for (const uid of users) {
    await db.recursiveDelete(db.doc(`users/${uid}`));
    await auth.deleteUser(uid);
  }
}
