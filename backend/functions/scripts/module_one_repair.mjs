/**
 * Local repair for children left above module 1 without a current
 * full-curriculum entitlement (ADR 0025).
 *
 * The repair changes only the journey pointer: currentCourseId/currentLessonId
 * move to module 1's first lesson. learningLevel, progress, sessions, attempts,
 * rewards, assessment results and bookmarks are preserved. Previous pointer
 * values are stored in a server-owned repair document so rollback can restore
 * them. Emulator-only; output contains aggregate counts, never child data.
 */
import { FieldValue } from "firebase-admin/firestore";

import { canAccessModuleForUser } from "../lib/learning/lesson_access.js";

export const REPAIR_DOC_ID = "moduleOneRepair";
export const REPAIR_FLOW_VERSION = "module-one-repair-v1";

async function loadContent(db) {
  const [modules, lessons] = await Promise.all([
    db.collection("modules").get(),
    db.collection("lessons").get(),
  ]);
  const moduleById = new Map(modules.docs.map((document) => [document.id, document.data()]));
  const lessonById = new Map(lessons.docs.map((document) => [document.id, document.data()]));
  const freeModule = modules.docs.find((document) =>
    document.get("published") === true && document.get("number") === 1,
  );
  const firstLessonId = freeModule?.get("firstLessonId");
  const courseId = freeModule?.get("courseId");
  return {
    moduleById,
    lessonById,
    freeModule: freeModule
      ? {
          id: freeModule.id,
          courseId: typeof courseId === "string" ? courseId : null,
          firstLessonId: typeof firstLessonId === "string" ? firstLessonId : null,
        }
      : null,
  };
}

function classifyChild(child, content) {
  const currentLessonId = child.get("currentLessonId");
  if (typeof currentLessonId !== "string" || currentLessonId.length === 0) {
    return { kind: "unknown" };
  }
  const lesson = content.lessonById.get(currentLessonId);
  if (!lesson) return { kind: "unknown" };
  const moduleId = lesson.moduleId;
  const module = typeof moduleId === "string" ? content.moduleById.get(moduleId) : undefined;
  if (!module || module.published !== true) return { kind: "unknown" };
  const moduleNumber = module.number;
  if (moduleNumber === 1) return { kind: "free", lesson, module };
  if (typeof moduleNumber !== "number" || !Number.isInteger(moduleNumber) ||
      moduleNumber < 2) {
    return { kind: "unknown" };
  }
  return { kind: "premium", lesson, module };
}

async function scan(db) {
  const content = await loadContent(db);
  const users = await db.collection("users").get();
  const rows = [];
  let childrenScanned = 0;
  let unknown = 0;
  const byModule = {};

  for (const user of users.docs) {
    const children = await user.ref.collection("children").get();
    for (const child of children.docs) {
      childrenScanned += 1;
      const classified = classifyChild(child, content);
      if (classified.kind === "unknown") {
        unknown += 1;
        continue;
      }
      if (classified.kind === "free") continue;
      const moduleNumber = classified.module.number;
      byModule[moduleNumber] = (byModule[moduleNumber] ?? 0) + 1;
      const hasAccess = await canAccessModuleForUser(user.id, moduleNumber);
      rows.push({
        uid: user.id,
        childId: child.id,
        childRef: child.ref,
        lessonId: child.get("currentLessonId"),
        courseId: child.get("currentCourseId") ?? null,
        moduleNumber,
        eligible: !hasAccess,
      });
    }
  }
  return { content, rows, childrenScanned, unknown, byModule };
}

function summarize(rows, childrenScanned, unknown, byModule) {
  return {
    childrenScanned,
    candidates: rows.filter((row) => row.eligible).length,
    entitled: rows.filter((row) => !row.eligible).length,
    unknown,
    byModule,
  };
}

/** Aggregate inventory; no child names, e-mail or UIDs are returned. */
export async function inventoryModuleOneRepairs(db) {
  const scanResult = await scan(db);
  if (!scanResult.content.freeModule?.firstLessonId) {
    throw new Error("Module 1 has no published firstLessonId");
  }
  return {
    usersScanned: (await db.collection("users").get()).size,
    ...summarize(
      scanResult.rows,
      scanResult.childrenScanned,
      scanResult.unknown,
      scanResult.byModule,
    ),
    freeLessonId: scanResult.content.freeModule.firstLessonId,
  };
}

/**
 * Plans or applies the pointer-only repair. Re-running is a no-op once the
 * child is on module 1. The repair document keeps the previous pointers for
 * an explicit rollback; progress is never touched.
 */
export async function repairModuleOnePlacements(db, { apply = false } = {}) {
  const scanResult = await scan(db);
  const freeModule = scanResult.content.freeModule;
  if (!freeModule?.firstLessonId) {
    throw new Error("Module 1 has no published firstLessonId");
  }
  const result = {
    mode: apply ? "apply" : "dry-run",
    usersScanned: (await db.collection("users").get()).size,
    ...summarize(
      scanResult.rows,
      scanResult.childrenScanned,
      scanResult.unknown,
      scanResult.byModule,
    ),
    repaired: 0,
  };

  if (!apply) return result;

  for (const row of scanResult.rows.filter((entry) => entry.eligible)) {
    const repairRef = db
      .doc(`users/${row.uid}`)
      .collection("migrations")
      .doc(REPAIR_DOC_ID);
    const previous = await repairRef.get();
    const children = { ...(previous.get("children") ?? {}) };
    children[row.childId] = {
      previousCourseId: row.courseId,
      previousLessonId: row.lessonId,
    };
    await repairRef.set({
      schemaVersion: 1,
      flowVersion: REPAIR_FLOW_VERSION,
      repairedAt: FieldValue.serverTimestamp(),
      children,
    }, { merge: true });

    await row.childRef.update({
      currentCourseId: freeModule.courseId,
      currentLessonId: freeModule.firstLessonId,
      updatedAt: FieldValue.serverTimestamp(),
    });
    result.repaired += 1;
  }
  return result;
}

/** Restores only the pointers recorded by the repair; progress stays intact. */
export async function rollbackModuleOneRepairs(db) {
  const users = await db.collection("users").get();
  const result = {
    usersScanned: users.size,
    repairDocuments: 0,
    restored: 0,
    skipped: 0,
  };

  for (const user of users.docs) {
    const repairRef = user.ref.collection("migrations").doc(REPAIR_DOC_ID);
    const repair = await repairRef.get();
    if (!repair.exists) continue;
    result.repairDocuments += 1;
    const children = repair.get("children");
    if (!children || typeof children !== "object") {
      await repairRef.delete();
      continue;
    }
    for (const [childId, entry] of Object.entries(children)) {
      const previous = entry && typeof entry === "object"
        ? entry
        : {};
      const lessonId = previous.previousLessonId;
      if (typeof lessonId !== "string" || lessonId.length === 0) {
        result.skipped += 1;
        continue;
      }
      const childRef = user.ref.collection("children").doc(childId);
      if (!(await childRef.get()).exists) {
        result.skipped += 1;
        continue;
      }
      await childRef.update({
        currentCourseId: typeof previous.previousCourseId === "string"
          ? previous.previousCourseId
          : null,
        currentLessonId: lessonId,
        updatedAt: FieldValue.serverTimestamp(),
      });
      result.restored += 1;
    }
    await repairRef.delete();
  }
  return result;
}
