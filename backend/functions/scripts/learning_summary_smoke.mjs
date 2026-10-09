/** Emulator integration: lifecycle retries, active time and atomic daily totals. */
import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { initializeApp, getApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

for (const key of ["FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST"]) {
  assert.match(process.env[key] ?? "", /^(localhost|127\.0\.0\.1):\d+$/);
}
const project = "demo-letrando";
initializeApp({ projectId: project });
const auth = getAuth();
const db = getFirestore();
const fixtures = [];
async function parent() {
  const password = randomBytes(24).toString("base64url");
  const user = await auth.createUser({ email: `summary-${randomBytes(6).toString("hex")}@example.test`,
    password, emailVerified: true });
  fixtures.push(user.uid);
  for (let attempt = 0; attempt < 50; attempt++) {
    if ((await db.doc(`users/${user.uid}`).get()).get("onboardingState")) break;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  const login = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-api-key`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email: user.email, password, returnSecureToken: true }),
  }).then((response) => response.json());
  assert.ok(login.idToken);
  await db.doc(`users/${user.uid}`).update({ timezone: "America/Belem" });
  return { uid: user.uid, token: login.idToken };
}
async function call(name, owner, data) {
  return fetch(`http://127.0.0.1:5001/${project}/southamerica-east1/${name}`, {
    method: "POST", headers: { Authorization: `Bearer ${owner.token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ data }),
  }).then((response) => response.json());
}
function milliseconds(session) {
  return Object.values(session.activeMillisecondsByDate ?? {}).reduce((sum, value) => sum + value, 0);
}
try {
  const owner = await parent();
  const stranger = await parent();
  const created = await call("createChildProfile", owner, {
    requestId: randomBytes(12).toString("hex"), profile: { name: "Leitor", age: 5, avatarId: "teal" },
  });
  const childId = created.result?.childId;
  assert.ok(childId);
  assert.ok((await call("submitAssessment", owner, { childId, answers: {
    q_letters: "some", q_writes_name: "not_yet", q_reading_together: "rarely",
  } })).result);
  const lessonId = "lesson_001";
  const started = await call("startLessonSession", owner, { lessonId, childId });
  const sessionId = started.result?.sessionId;
  assert.ok(sessionId);
  const sessionRef = db.doc(`users/${owner.uid}/sessions/${sessionId}`);
  const lifecycle = (action, sequence, who = owner) => call("updateLessonSession", who,
    { sessionId, childId, action, sequence });
  assert.equal((await lifecycle("heartbeat", 1, stranger)).error?.status, "NOT_FOUND");
  await sessionRef.update({ lastActiveAt: Timestamp.fromMillis(Date.now() - 60_000) });
  assert.equal((await lifecycle("heartbeat", 1)).result?.ok, true);
  const credited = (await sessionRef.get()).data();
  assert.equal(milliseconds(credited), 30_000);
  assert.equal((await lifecycle("heartbeat", 1)).result?.ok, true);
  assert.equal(milliseconds((await sessionRef.get()).data()), 30_000);
  await lifecycle("pause", 2);
  const pausedTime = milliseconds((await sessionRef.get()).data());
  await sessionRef.update({ lastActiveAt: Timestamp.fromMillis(Date.now() - 3600_000) });
  await lifecycle("resume", 3);
  assert.equal(milliseconds((await sessionRef.get()).data()), pausedTime);
  await lifecycle("pause", 2); // delayed duplicate cannot undo the newer resume
  assert.equal((await sessionRef.get()).get("status"), "active");
  const lastActivity = (await sessionRef.get()).get("activityIds")[3];
  const lastContent = (await db.doc(`activities/${lastActivity}`).get()).data();
  assert.equal((await call("submitActivityAttempt", owner, { childId, sessionId,
    activityId: lastActivity, requestId: randomBytes(12).toString("hex"),
    response: { selectedLabel: lastContent.options.find((option) => option.correct).label },
  })).error?.status, "FAILED_PRECONDITION");

  async function answerAll(id) {
    const session = (await db.doc(`users/${owner.uid}/sessions/${id}`).get()).data();
    for (const activityId of session.activityIds) {
      const activity = (await db.doc(`activities/${activityId}`).get()).data();
      const responses = activity.type === "match" ? activity.pairs : activity.type === "trace"
        ? [{ strokeCount: 1, pointCount: 8, durationMillis: 500 }]
        : [{ selectedLabel: activity.options.find((option) => option.correct).label }];
      for (const response of responses) {
        assert.equal((await call("submitActivityAttempt", owner, { childId, sessionId: id,
          activityId, requestId: randomBytes(12).toString("hex"), response })).result?.correct, true);
      }
    }
  }
  await answerAll(sessionId);
  const complete = (id) => call("completeLesson", owner, { lessonId, childId, sessionId: id });
  const parallel = await Promise.all([complete(sessionId), complete(sessionId)]);
  assert.equal(parallel.filter((response) => response.result?.awarded).length, 1);
  const week = (await call("getWeeklyLearningSummary", owner, { childId })).result;
  assert.ok(week, "New summary callable must be loaded by the Functions emulator");
  assert.ok(week.refreshAfterMilliseconds > 0 && week.refreshAfterMilliseconds <= 27 * 3600_000);
  assert.equal(week.days.reduce((sum, day) => sum + day.lessonsCompleted, 0), 1);
  assert.equal(week.days.reduce((sum, day) => sum + day.sessionsCompleted, 0), 1);
  const completedSession = (await sessionRef.get()).data();
  const summaries = await db.collection(`users/${owner.uid}/children/${childId}/dailySummaries`).get();
  assert.equal(summaries.docs.reduce((sum, doc) => sum + doc.get("activeMilliseconds"), 0), milliseconds(completedSession));
  await complete(sessionId);
  const retry = (await call("getWeeklyLearningSummary", owner, { childId })).result;
  assert.deepEqual(retry.days, week.days);
  assert.equal((await call("getWeeklyLearningSummary", stranger, { childId })).error?.status, "NOT_FOUND");

  const progressRef = db.doc(`users/${owner.uid}/learningProgress/${childId}_${lessonId}`);
  const firstCompletion = (await progressRef.get()).get("completedAt").toMillis();
  const replayId = (await call("startLessonSession", owner, { childId, lessonId })).result?.sessionId;
  assert.ok(replayId);
  await answerAll(replayId);
  assert.equal((await complete(replayId)).result?.awarded, false);
  const replayWeek = (await call("getWeeklyLearningSummary", owner, { childId })).result;
  assert.equal(replayWeek.days.reduce((sum, day) => sum + day.lessonsCompleted, 0), 1);
  assert.equal(replayWeek.days.reduce((sum, day) => sum + day.sessionsCompleted, 0), 2);
  assert.equal((await progressRef.get()).get("completedAt").toMillis(), firstCompletion);
  console.log("Learning summaries passed: bounded presence, pause/resume, delayed retries, ownership, parallel completion, replay and exact daily totals.");
} finally {
  for (const uid of fixtures) {
    await db.recursiveDelete(db.doc(`users/${uid}`));
    await auth.deleteUser(uid);
  }
  await getApp().delete();
}
