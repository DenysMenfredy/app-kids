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
  Timestamp,
  collection,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  where,
} from "firebase/firestore";

/** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
let env;

const PARENT = "parent_uid";
const STRANGER = "stranger_uid";

before(async () => {
  env = await initializeTestEnvironment({
    // Separate from ./dev.sh: sharing a project ID overwrites the live
    // emulator hub's locator file even when the ports are different.
    projectId: "demo-letrando-rules",
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
const asVerifiedParent = () => env.authenticatedContext(PARENT, {
  email_verified: true,
}).firestore();
const asStranger = () => env.authenticatedContext(STRANGER).firestore();
const asAnon = () => env.unauthenticatedContext().firestore();
const asAdmin = (fn) => env.withSecurityRulesDisabled(fn);

describe("server-owned per-child daily summaries", () => {
  it("allows only the current parent and prevents forged totals and orphan reads", async () => {
    const path = `users/${PARENT}/children/child1/dailySummaries/2026-10-09`;
    await asAdmin(async (ctx) => {
      await ctx.firestore().doc(`users/${PARENT}/children/child1`).set({ name: "Leitor", age: 5 });
      await ctx.firestore().doc(path).set({ lessonsCompleted: 1, activeMilliseconds: 60_000 });
    });
    await assertSucceeds(asParent().doc(path).get());
    await assertFails(asStranger().doc(path).get());
    await assertFails(asAnon().doc(path).get());
    await assertFails(asParent().doc(path).update({ lessonsCompleted: 99 }));
    await assertFails(asParent().doc(path).delete());
    await assertFails(asParent().doc(path.replace("2026-10-09", "2026-10-10")).set({ lessonsCompleted: 99 }));
    await asAdmin((ctx) => ctx.firestore().doc(`users/${PARENT}/children/child1`).delete());
    await assertFails(asParent().doc(path).get());
  });
});

describe("book catalog, protected pages and child bookmarks", () => {
  beforeEach(async () => {
    await asAdmin(async (ctx) => {
      const db = ctx.firestore();
      await db.doc(`users/${PARENT}/children/child1`).set({ name: "Lucas", age: 4, avatarId: "orange" });
      for (const [id, access, published] of [
        ["free", "free", true], ["premium", "premium", true], ["draft", "free", false],
      ]) {
        await db.doc(`books/${id}`).set({
          published, access, schemaVersion: 1, contentVersion: 1, pageCount: 1,
        });
        await db.doc(`bookContents/${id}`).set({
          published, schemaVersion: 1, contentVersion: 1,
          pages: [{ id: "p1", text: "Uma história.", illustration: "book" }],
        });
      }
      await db.doc(`users/${PARENT}/children/child1/bookmarks/free`).set({
        bookId: "free", contentVersion: 1, pageIndex: 0,
      });
    });
  });

  it("lists published covers without exposing Premium pages", async () => {
    const snapshot = await assertSucceeds(getDocs(query(collection(asParent(), "books"),
      where("published", "==", true))));
    assert.equal(snapshot.size, 2);
    await assertFails(getDocs(collection(asParent(), "books")));
    await assertFails(asParent().doc("books/draft").get());
    await assertFails(asAnon().doc("books/free").get());
    await assertSucceeds(asParent().doc("bookContents/free").get());
    await assertFails(asParent().doc("bookContents/premium").get());
    await assertFails(getDocs(collection(asParent(), "bookContents")));
    await assertFails(asAnon().doc("bookContents/free").get());
  });

  it("requires the current premium_books entitlement and excludes other families", async () => {
    const valid = {
      active: true, features: ["premium_books"],
      validFrom: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      validUntil: Timestamp.fromDate(new Date(Date.now() + 60_000)),
    };
    const setEntitlement = (data) => asAdmin((ctx) => ctx.firestore()
      .doc(`users/${PARENT}/entitlements/premium`).set(data));
    await setEntitlement(valid);
    await assertSucceeds(asParent().doc("bookContents/premium").get());
    await assertFails(asStranger().doc("bookContents/premium").get());
    for (const invalid of [
      { ...valid, active: false }, { ...valid, features: ["full_curriculum"] },
      { ...valid, validUntil: Timestamp.fromDate(new Date(0)) },
      { ...valid, validFrom: Timestamp.fromDate(new Date(Date.now() + 60_000)) },
    ]) {
      await setEntitlement(invalid);
      await assertFails(asParent().doc("bookContents/premium").get());
    }
  });

  it("denies drafts, missing classifications, mismatched versions and page counts", async () => {
    await assertFails(asParent().doc("bookContents/draft").get());
    for (const change of [
      { published: false }, { access: "unknown" }, { contentVersion: 2 },
      { pageCount: 0 }, { pageCount: 2 }, { schemaVersion: 2 },
    ]) {
      await asAdmin((ctx) => ctx.firestore().doc("books/free").set({
        published: true, access: "free", schemaVersion: 1, contentVersion: 1, pageCount: 1,
        ...change,
      }));
      await assertFails(asParent().doc("bookContents/free").get());
    }
    await asAdmin((ctx) => ctx.firestore().doc("books/free").delete());
    await assertFails(asParent().doc("bookContents/free").get());
  });

  it("limits bookmarks to the parent and existing child; direct writes are denied", async () => {
    const path = `users/${PARENT}/children/child1/bookmarks/free`;
    await assertSucceeds(asParent().doc(path).get());
    await assertSucceeds(getDocs(collection(asParent(), `users/${PARENT}/children/child1/bookmarks`)));
    await assertFails(asStranger().doc(path).get());
    await assertFails(asAnon().doc(path).get());
    await assertFails(asParent().doc(path).update({ pageIndex: 999 }));
    await assertFails(asParent().doc(path).delete());
    await assertFails(asParent().doc(`users/${PARENT}/children/child1/bookmarks/new`).set({ pageIndex: 0 }));
    await assertFails(asParent().doc("books/free").update({ access: "free" }));
    await assertFails(asParent().doc("bookContents/premium").set({ published: true, pages: [] }));
    await asAdmin((ctx) => ctx.firestore().doc(`users/${PARENT}/children/child1`).delete());
    await assertFails(asParent().doc(path).get());
  });
});

describe("user profile", () => {
  it("owner can read and write own profile with allowed fields", async () => {
    await assertSucceeds(
      asParent().doc(`users/${PARENT}`).set({
        displayName: "Camila",
        locale: "pt-BR",
        timezone: "America/Sao_Paulo",
        onboardingState: "created",
      }),
    );
    await asAdmin((ctx) =>
      ctx.firestore().doc(`users/${PARENT}`).set({
        email: "pai@example.com", createdAt: new Date(),
      }, { merge: true }),
    );
    await assertSucceeds(
      asParent().doc(`users/${PARENT}`).set({ displayName: "Camila Silva" }, { merge: true }),
    );
    await assertSucceeds(asParent().doc(`users/${PARENT}`).get());
  });

  it("client cannot create or change Auth email and creation timestamp", async () => {
    await assertFails(asParent().doc(`users/${PARENT}`).set({ email: "fake@example.com" }));
    await asAdmin((ctx) =>
      ctx.firestore().doc(`users/${PARENT}`).set({
        email: "real@example.com", createdAt: new Date(),
      }),
    );
    await assertFails(asParent().doc(`users/${PARENT}`).update({ email: "fake@example.com" }));
    await assertFails(asParent().doc(`users/${PARENT}`).update({ createdAt: new Date(0) }));
  });

  it("rejects malformed mutable profile fields and forged update times", async () => {
    const ref = asParent().doc(`users/${PARENT}`);
    await assertFails(ref.set({ displayName: "x".repeat(121) }));
    await assertFails(ref.set({ timezone: 123 }));
    await assertFails(ref.set({ displayName: "Camila", updatedAt: new Date(0) }));
    await assertSucceeds(ref.set({ displayName: "Camila" }));
    await assertFails(ref.update({ updatedAt: new Date(0) }));
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
  it("parent cannot choose child IDs, but can edit a server-created profile", async () => {
    await asAdmin((ctx) =>
      ctx.firestore().doc(`users/${PARENT}/children/generated-id`).set({
        name: "Lucas",
        age: 4,
        avatarId: "orange",
      }),
    );
    const child = asVerifiedParent().doc(`users/${PARENT}/children/generated-id`);
    await assertFails(
      asParent().doc(`users/${PARENT}/children/client-chosen-id`).set({
        name: "Lucas", age: 4, avatarId: "orange",
      }),
    );
    await assertFails(
      asParent().doc(`users/${PARENT}/children/generated-id`).update({
        name: "Lucas A.", avatarId: "teal",
      }),
    );
    await assertSucceeds(child.update({ name: "Lucas A.", avatarId: "teal" }));
  });

  it("parent edits only the minimum-data schema on a server-created child", async () => {
    await asAdmin((ctx) =>
      ctx.firestore().doc(`users/${PARENT}/children/child1`).set({
        name: "Lucas",
        birthDate: "2022-04-15",
        age: 4,
        avatarId: "orange",
      }),
    );
    await asAdmin((ctx) =>
      ctx.firestore().doc(`users/${PARENT}/children/child1`).set({
        learningLevel: "pre_literacy", currentLessonId: "lesson_001",
      }, { merge: true }),
    );
    await assertSucceeds(
      asVerifiedParent().doc(`users/${PARENT}/children/child1`).set({
        name: "Lucas A.", avatarId: "teal",
      }, { merge: true }),
    );
  });

  it("denies placement and journey mutations on create, merge, replace and delete", async () => {
    const ref = asVerifiedParent().doc(`users/${PARENT}/children/child1`);
    await assertFails(ref.set({ name: "Lucas", currentLessonId: "lesson_037" }));
    await asAdmin((ctx) =>
      ctx.firestore().doc(`users/${PARENT}/children/child1`).set({
        name: "Lucas", age: 4, avatarId: "lion_01",
        learningLevel: "pre_literacy", currentCourseId: "course_001",
        currentLessonId: "lesson_001",
      }),
    );
    await assertFails(ref.set({ currentLessonId: "lesson_037" }, { merge: true }));
    await assertFails(ref.update({ learningLevel: "advanced" }));
    await assertFails(ref.set({ name: "Lucas", age: 4, avatarId: "lion_01" }));
    await assertFails(ref.delete());
  });

  it("rejects invalid child names, ages, avatars and timestamps", async () => {
    const ref = asVerifiedParent().doc(`users/${PARENT}/children/child1`);
    await asAdmin((ctx) =>
      ctx.firestore().doc(`users/${PARENT}/children/child1`).set({
        name: "Lucas", age: 4, avatarId: "orange",
      }),
    );
    await assertFails(ref.update({ name: "" }));
    await assertFails(ref.update({ age: 2 }));
    await assertFails(ref.update({ avatarId: 99 }));
    await assertFails(ref.update({ updatedAt: new Date(0) }));
    await assertFails(ref.update({ age: 8 }));
  });

  it("rejects child documents with forbidden PII fields", async () => {
    await asAdmin((ctx) =>
      ctx.firestore().doc(`users/${PARENT}/children/child1`).set({
        name: "Lucas", age: 4, avatarId: "orange",
      }),
    );
    await assertFails(
      asVerifiedParent().doc(`users/${PARENT}/children/child1`).update({
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
  it("owner reads server-owned progress, attempts and sessions but cannot write them", async () => {
    const paths = [
      `users/${PARENT}/learningProgress/child1_lesson1`,
      `users/${PARENT}/activityAttempts/a1`,
      `users/${PARENT}/sessions/s1`,
    ];
    await asAdmin(async (ctx) => {
      for (const path of paths) await ctx.firestore().doc(path).set({ childId: "child1" });
    });
    for (const path of paths) {
      await assertSucceeds(asParent().doc(path).get());
      await assertFails(asParent().doc(path).set({ childId: "child1", status: "completed" }, { merge: true }));
      await assertFails(asParent().doc(path).delete());
      await assertFails(asStranger().doc(path).get());
    }
    await assertFails(
      asParent().doc(`users/${PARENT}/learningProgress/invented`).set({ status: "completed" }),
    );
    await assertFails(asParent().doc(`users/${PARENT}/activityAttempts/invented`).set({ correct: true }));
    await assertFails(asParent().doc(`users/${PARENT}/sessions/invented`).set({ childId: "child1" }));
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

  it("published stories are readable, drafts are not", async () => {
    await asAdmin(async (ctx) => {
      const db = ctx.firestore();
      const { doc, setDoc } = await import("firebase/firestore");
      await setDoc(doc(db, "modules/module_007"), {
        number: 7, published: true,
      });
      await setDoc(doc(db, "lessons/lesson_032"), {
        moduleId: "module_007", published: true,
      });
      await setDoc(doc(db, "stories/story_001"), {
        lessonId: "lesson_032", title: "A Lua", published: true,
      });
      await setDoc(doc(db, "stories/draft"), {
        lessonId: "lesson_032", title: "Rascunho", published: false,
      });
    });
    await assertFails(asParent().doc("stories/story_001").get());
    await assertFails(asParent().doc("stories/draft").get());
    await assertFails(asAnon().doc("stories/story_001").get());
    await asAdmin((ctx) => ctx.firestore()
      .doc(`users/${PARENT}/entitlements/premium`)
      .set({
        active: true,
        features: ["full_curriculum"],
        validFrom: Timestamp.fromDate(new Date(Date.now() - 60_000)),
        validUntil: Timestamp.fromDate(new Date(Date.now() + 60_000)),
      }));
    await assertSucceeds(asParent().doc("stories/story_001").get());
  });

  it("clients cannot write stories", async () => {
    await assertFails(
      asParent().doc("stories/story_001").set({ title: "hack", published: true }),
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
      await setDoc(doc(db, "modules/module_001"), {
        number: 1, published: true,
      });
      await setDoc(doc(db, "lessons/lesson_001"), {
        moduleId: "module_001", published: true,
      });
      await setDoc(doc(db, "activities/a1"), {
        lessonId: "lesson_001", type: "tap", order: 1, published: true,
      });
      await setDoc(doc(db, "activities/a2"), {
        lessonId: "lesson_001", type: "match", order: 2, published: true,
      });
      await setDoc(doc(db, "activities/draft"), {
        lessonId: "lesson_001", type: "trace", order: 3, published: false,
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
            where("lessonId", "==", "lesson_001"),
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
          where("lessonId", "==", "lesson_001"),
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

  it("blocks Premium payloads until the owner has a current entitlement", async () => {
    await asAdmin(async (ctx) => {
      const db = ctx.firestore();
      const { doc, setDoc } = await import("firebase/firestore");
      await setDoc(doc(db, "modules/module_002"), {
        number: 2, published: true,
      });
      await setDoc(doc(db, "lessons/lesson_004"), {
        moduleId: "module_002", published: true,
      });
      await setDoc(doc(db, "activities/premium_tap"), {
        lessonId: "lesson_004", type: "tap", order: 1, published: true,
      });
    });
    await assertFails(asParent().doc("activities/premium_tap").get());
    await assertFails(getDocs(query(
      collection(asParent(), "activities"),
      where("lessonId", "==", "lesson_004"),
      where("published", "==", true),
    )));

    await asAdmin((ctx) => ctx.firestore()
      .doc(`users/${PARENT}/entitlements/premium`)
      .set({
        active: true,
        features: ["full_curriculum"],
        validFrom: Timestamp.fromDate(new Date(Date.now() - 60_000)),
        validUntil: Timestamp.fromDate(new Date(Date.now() + 60_000)),
      }));
    await assertSucceeds(asParent().doc("activities/premium_tap").get());
    const snapshot = await assertSucceeds(getDocs(query(
      collection(asParent(), "activities"),
      where("lessonId", "==", "lesson_004"),
      where("published", "==", true),
    )));
    assert.equal(snapshot.size, 1);
  });

  it("denies expired and feature-incomplete entitlement documents", async () => {
    await asAdmin(async (ctx) => {
      const db = ctx.firestore();
      const { doc, setDoc } = await import("firebase/firestore");
      await setDoc(doc(db, "modules/module_002"), {
        number: 2, published: true,
      });
      await setDoc(doc(db, "lessons/lesson_004"), {
        moduleId: "module_002", published: true,
      });
      await setDoc(doc(db, "activities/premium_tap"), {
        lessonId: "lesson_004", type: "tap", order: 1, published: true,
      });
      await setDoc(doc(db, `users/${PARENT}/entitlements/premium`), {
        active: true,
        features: ["premium_books"],
        validFrom: Timestamp.fromDate(new Date(Date.now() - 120_000)),
        validUntil: Timestamp.fromDate(new Date(Date.now() - 60_000)),
      });
    });
    await assertFails(asParent().doc("activities/premium_tap").get());
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
        timezone: "America/Belem",
        updatedAt: serverTimestamp(),
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

  it("rejects malformed preferences, forged timestamps and other parents", async () => {
    const path = `users/${PARENT}/notificationPreferences/default`;
    const valid = { dailyReminder: true, achievement: true, weeklyReport: true,
      subscription: true, marketing: false, preferredTime: "18:00",
      timezone: "America/Belem", updatedAt: serverTimestamp() };
    for (const change of [{ dailyReminder: "yes" }, { preferredTime: "99:99" },
      { timezone: "Unknown/Zone" }, { updatedAt: Timestamp.fromMillis(0) }, { role: "admin" }]) {
      await assertFails(asParent().doc(path).set({ ...valid, ...change }));
    }
    await assertFails(asStranger().doc(path).set(valid));
  });

  it("keeps installation ownership and token registries server-only", async () => {
    for (const path of ["notificationInstallations/test", "notificationTokens/test"]) {
      await asAdmin((ctx) => ctx.firestore().doc(path).set({ uid: PARENT }));
      await assertFails(asParent().doc(path).get());
      await assertFails(asParent().doc(path).set({ uid: PARENT }));
      await assertFails(asParent().doc(path).delete());
    }
  });
});

// Keep node:test happy when the file is loaded without the emulator.
assert.ok(true);
