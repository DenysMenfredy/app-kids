/**
 * Firestore Security Rules tests (spec §24: automated
 * authorized/unauthorized tests). Requires the Firestore emulator:
 *
 *   cd backend/test/rules && npm install && npm test
 *
 * (firebase-tools + Java 11+ required for the emulator.)
 */
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { after, before, beforeEach, describe, it } from "node:test";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collection,
  getDocs,
  orderBy,
  query,
  where,
} from "firebase/firestore";

/** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
let env;

const PARENT = "parent_uid";
const STRANGER = "stranger_uid";

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "letrando-dev",
    firestore: {
      rules: readFileSync(new URL("../../firestore.rules", import.meta.url), "utf8"),
    },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

const asParent = () => env.authenticatedContext(PARENT).firestore();
const asStranger = () => env.authenticatedContext(STRANGER).firestore();
const asAnon = () => env.unauthenticatedContext().firestore();
const asAdmin = (fn) => env.withSecurityRulesDisabled(fn);

describe("user profile", () => {
  it("owner can read and write own profile with allowed fields", async () => {
    await assertSucceeds(
      asParent().doc(`users/${PARENT}`).set({
        email: "pai@example.com",
        displayName: "Camila",
        locale: "pt-BR",
        timezone: "America/Sao_Paulo",
        onboardingState: "created",
      }),
    );
    await assertSucceeds(asParent().doc(`users/${PARENT}`).get());
  });

  it("client cannot write privileged fields such as role", async () => {
    await assertFails(
      asParent().doc(`users/${PARENT}`).set({ displayName: "X", role: "admin" }),
    );
  });

  it("stranger cannot read another user's profile", async () => {
    await asAdmin((ctx) =>
      ctx.firestore().doc(`users/${PARENT}`).set({ email: "x@y.z" }),
    );
    await assertFails(asStranger().doc(`users/${PARENT}`).get());
  });
});

describe("children (parent/child boundary, spec §19)", () => {
  it("parent manages own children with the minimum-data schema", async () => {
    await assertSucceeds(
      asParent().doc(`users/${PARENT}/children/child1`).set({
        name: "Lucas",
        birthDate: "2022-04-15",
        age: 4,
        avatarId: "lion_01",
        learningLevel: "pre_literacy",
      }),
    );
  });

  it("rejects child documents with forbidden PII fields", async () => {
    await assertFails(
      asParent().doc(`users/${PARENT}/children/child1`).set({
        name: "Lucas",
        school: "Escola X", // not allowed by the child-data constraint
      }),
    );
  });

  it("stranger cannot touch another parent's children", async () => {
    await assertFails(
      asStranger().doc(`users/${PARENT}/children/child1`).get(),
    );
    await assertFails(
      asStranger().doc(`users/${PARENT}/children/child1`).set({ name: "X" }),
    );
  });
});

describe("subscriptions & entitlements (backend-only writes, spec §13)", () => {
  it("owner can read own subscription and entitlement", async () => {
    await asAdmin(async (ctx) => {
      await ctx
        .firestore()
        .doc(`users/${PARENT}/subscriptions/sub_1`)
        .set({ status: "active" });
      await ctx
        .firestore()
        .doc(`users/${PARENT}/entitlements/premium`)
        .set({ active: true });
    });
    await assertSucceeds(
      asParent().doc(`users/${PARENT}/subscriptions/sub_1`).get(),
    );
    await assertSucceeds(
      asParent().doc(`users/${PARENT}/entitlements/premium`).get(),
    );
  });

  it("client can NEVER write subscription or entitlement state", async () => {
    await assertFails(
      asParent()
        .doc(`users/${PARENT}/subscriptions/sub_1`)
        .set({ status: "active" }),
    );
    await assertFails(
      asParent()
        .doc(`users/${PARENT}/entitlements/premium`)
        .set({ active: true }),
    );
  });
});

describe("learning data", () => {
  it("accepts valid progress updates", async () => {
    await assertSucceeds(
      asParent().doc(`users/${PARENT}/learningProgress/child1_lesson1`).set({
        lessonId: "lesson1",
        childId: "child1",
        status: "in_progress",
        score: 87,
      }),
    );
  });

  it("rejects invalid status or out-of-range score", async () => {
    await assertFails(
      asParent()
        .doc(`users/${PARENT}/learningProgress/p1`)
        .set({ lessonId: "l", childId: "c", status: "hacked" }),
    );
    await assertFails(
      asParent()
        .doc(`users/${PARENT}/learningProgress/p2`)
        .set({ lessonId: "l", childId: "c", status: "completed", score: 999 }),
    );
  });

  it("activity attempts are immutable once created", async () => {
    const ref = asParent().doc(`users/${PARENT}/activityAttempts/a1`);
    await assertSucceeds(
      ref.set({
        activityId: "act1",
        lessonId: "l1",
        childId: "c1",
        correct: true,
        attemptNumber: 1,
      }),
    );
    await assertFails(ref.update({ correct: false }));
  });
});

describe("gamification & assessment results (server-owned, ADR 0003)", () => {
  it("owner can read their own XP/coins/streak", async () => {
    await asAdmin((ctx) =>
      ctx
        .firestore()
        .doc(`users/${PARENT}/gamification/primary`)
        .set({ xp: 50, coins: 10, streak: 1 }),
    );
    await assertSucceeds(
      asParent().doc(`users/${PARENT}/gamification/primary`).get(),
    );
  });

  it("client can NEVER mint XP, coins or streak", async () => {
    await assertFails(
      asParent()
        .doc(`users/${PARENT}/gamification/primary`)
        .set({ xp: 999999, coins: 999999, streak: 365 }),
    );
    await asAdmin((ctx) =>
      ctx
        .firestore()
        .doc(`users/${PARENT}/gamification/primary`)
        .set({ xp: 50, coins: 10, streak: 1 }),
    );
    await assertFails(
      asParent().doc(`users/${PARENT}/gamification/primary`).update({ xp: 999999 }),
    );
  });

  it("client cannot self-assign a placement", async () => {
    await assertFails(
      asParent()
        .doc(`users/${PARENT}/assessmentResults/primary`)
        .set({ score: 6, placement: { moduleNumber: 7 } }),
    );
  });

  it("stranger cannot read another family's progress", async () => {
    await asAdmin((ctx) =>
      ctx.firestore().doc(`users/${PARENT}/gamification/primary`).set({ xp: 50 }),
    );
    await assertFails(
      asStranger().doc(`users/${PARENT}/gamification/primary`).get(),
    );
    await assertFails(
      asStranger().doc(`users/${PARENT}/assessmentResults/primary`).get(),
    );
  });
});

describe("assessment content", () => {
  it("authenticated users read the published assessment", async () => {
    await asAdmin(async (ctx) => {
      await ctx
        .firestore()
        .doc("assessments/assessment_pre_literacy_v1")
        .set({ title: "Avaliação inicial", published: true, questions: [] });
      await ctx
        .firestore()
        .doc("assessments/draft_v2")
        .set({ title: "Rascunho", published: false });
    });
    await assertSucceeds(
      asParent().doc("assessments/assessment_pre_literacy_v1").get(),
    );
    await assertFails(asParent().doc("assessments/draft_v2").get());
    await assertFails(
      asAnon().doc("assessments/assessment_pre_literacy_v1").get(),
    );
  });

  it("clients cannot edit assessments or their weights", async () => {
    await assertFails(
      asParent()
        .doc("assessments/assessment_pre_literacy_v1")
        .set({ published: true, questions: [] }),
    );
  });
});

describe("educational content", () => {
  it("authenticated users read only published content", async () => {
    await asAdmin(async (ctx) => {
      await ctx
        .firestore()
        .doc("lessons/published1")
        .set({ title: "A", published: true });
      await ctx
        .firestore()
        .doc("lessons/draft1")
        .set({ title: "B", published: false });
    });
    await assertSucceeds(asParent().doc("lessons/published1").get());
    await assertFails(asParent().doc("lessons/draft1").get());
    await assertFails(asAnon().doc("lessons/published1").get());
  });

  it("clients cannot write content", async () => {
    await assertFails(
      asParent().doc("lessons/published1").set({ title: "hack" }),
    );
  });
});

describe("content queries (list, not just get)", () => {
  // Rules evaluate a list against the *query*, not each result, so a
  // `published` rule is only satisfiable when the query says so. Reading one
  // document proves nothing about this — which is how the app shipped a
  // query the rules rejected.
  beforeEach(async () => {
    await asAdmin(async (ctx) => {
      const db = ctx.firestore();
      const { doc, setDoc } = await import("firebase/firestore");
      await setDoc(doc(db, "activities/a1"), {
        lessonId: "lesson_014", type: "tap", order: 1, published: true,
      });
      await setDoc(doc(db, "activities/a2"), {
        lessonId: "lesson_014", type: "match", order: 2, published: true,
      });
      await setDoc(doc(db, "activities/draft"), {
        lessonId: "lesson_014", type: "trace", order: 3, published: false,
      });
    });
  });

  it("a lesson's activities can be queried when the query filters on published",
    async () => {
      const db = asParent();
      const snapshot = await assertSucceeds(
        getDocs(
          query(
            collection(db, "activities"),
            where("lessonId", "==", "lesson_014"),
            where("published", "==", true),
            orderBy("order"),
          ),
        ),
      );
      assert.equal(snapshot.size, 2, "unpublished activity must be excluded");
    });

  it("an unfiltered query over the same collection is denied", async () => {
    const db = asParent();
    await assertFails(
      getDocs(
        query(
          collection(db, "activities"),
          where("lessonId", "==", "lesson_014"),
          orderBy("order"),
        ),
      ),
    );
  });

  it("an anonymous visitor cannot query content at all", async () => {
    await assertFails(
      getDocs(
        query(
          collection(asAnon(), "activities"),
          where("published", "==", true),
        ),
      ),
    );
  });
});

describe("backend-internal collections", () => {
  it("webhookEvents are invisible to all clients", async () => {
    await assertFails(asParent().doc("webhookEvents/stripe_evt_1").get());
    await assertFails(
      asParent().doc("webhookEvents/stripe_evt_1").set({ processed: true }),
    );
  });

  it("unknown collections are denied by default", async () => {
    await assertFails(asParent().doc("adminAuditLogs/log1").get());
    await assertFails(asParent().doc("randomStuff/x").set({ a: 1 }));
  });
});

describe("devices & notifications", () => {
  it("owner reads devices but cannot write them (callable-only)", async () => {
    await asAdmin((ctx) =>
      ctx
        .firestore()
        .doc(`users/${PARENT}/devices/d1`)
        .set({ platform: "ios" }),
    );
    await assertSucceeds(asParent().doc(`users/${PARENT}/devices/d1`).get());
    await assertFails(
      asParent().doc(`users/${PARENT}/devices/d2`).set({ platform: "ios" }),
    );
  });

  it("owner manages own notification preferences", async () => {
    await assertSucceeds(
      asParent().doc(`users/${PARENT}/notificationPreferences/default`).set({
        dailyReminder: true,
        achievement: true,
        weeklyReport: true,
        subscription: true,
        marketing: false,
        preferredTime: "18:00",
      }),
    );
  });

  it("notifications are read-only for the owner", async () => {
    await assertFails(
      asParent()
        .doc(`users/${PARENT}/notifications/n1`)
        .set({ title: "fake" }),
    );
  });
});

// Keep node:test happy when the file is loaded without the emulator.
assert.ok(true);
