/**
 * Local fixture rehearsal for the legacy `primary` child migration.
 *
 * The legacy document and every legacy child-scoped reference are kept in
 * place for old clients. A server-issued child ID receives copies plus a
 * readable mapping document; rollback deletes only those copies. This is a
 * rehearsal tool, not a production data migration: it refuses non-emulator
 * runs and reports aggregate counts only (no names, e-mail or UIDs).
 */
import { FieldValue } from "firebase-admin/firestore";

export const PRIMARY_CHILD_ID = "primary";
export const MIGRATION_DOC_ID = "primaryChild";
export const MIGRATION_FLOW_VERSION = "primary-migration-v1";

const REFERENCE_KEYS = [
  "sessions",
  "learningProgress",
  "activityAttempts",
  "gamification",
  "assessmentResults",
  "bookmarks",
  "dailySummaries",
  "childCreationRequests",
];

function emptyCounts() {
  return Object.fromEntries(REFERENCE_KEYS.map((key) => [key, 0]));
}

function totalCounts(counts) {
  return REFERENCE_KEYS.reduce((sum, key) => sum + (counts[key] ?? 0), 0);
}

function hasPrimaryReference(document) {
  return document.get("childId") === PRIMARY_CHILD_ID ||
    document.id.startsWith(`${PRIMARY_CHILD_ID}_`);
}

async function collectUserReferences(db, uid, primaryExists) {
  const userRef = db.doc(`users/${uid}`);
  const sessions = await userRef.collection("sessions").get();
  const primarySessionIds = new Set(
    sessions.docs
      .filter((document) => document.get("childId") === PRIMARY_CHILD_ID)
      .map((document) => document.id),
  );
  const learningProgress = await userRef.collection("learningProgress").get();
  const activityAttempts = await userRef.collection("activityAttempts").get();
  const gamification = await userRef.collection("gamification").doc(PRIMARY_CHILD_ID).get();
  const assessmentResults = await userRef
    .collection("assessmentResults")
    .doc(PRIMARY_CHILD_ID)
    .get();
  const childCreationRequests = await userRef.collection("childCreationRequests").get();

  const counts = {
    sessions: primarySessionIds.size,
    learningProgress: learningProgress.docs.filter(hasPrimaryReference).length,
    activityAttempts: activityAttempts.docs.filter((document) =>
      document.get("childId") === PRIMARY_CHILD_ID ||
      primarySessionIds.has(document.get("sessionId")),
    ).length,
    gamification: gamification.exists ? 1 : 0,
    assessmentResults: assessmentResults.exists ? 1 : 0,
    bookmarks: 0,
    dailySummaries: 0,
    childCreationRequests: childCreationRequests.docs.filter((document) =>
      document.get("childId") === PRIMARY_CHILD_ID,
    ).length,
  };

  if (primaryExists) {
    const primaryRef = userRef.collection("children").doc(PRIMARY_CHILD_ID);
    counts.bookmarks = (await primaryRef.collection("bookmarks").get()).size;
    counts.dailySummaries = (await primaryRef.collection("dailySummaries").get()).size;
  }
  return counts;
}

/** Aggregate inventory. It never returns a child name, e-mail or UID. */
export async function inventoryPrimaryChildren(db) {
  const users = await db.collection("users").get();
  const references = emptyCounts();
  const orphanReferences = emptyCounts();
  let usersWithPrimary = 0;
  let primaryChildren = 0;
  let orphanUsers = 0;

  for (const user of users.docs) {
    const primary = await user.ref.collection("children").doc(PRIMARY_CHILD_ID).get();
    const userReferences = await collectUserReferences(db, user.id, primary.exists);
    if (primary.exists) {
      primaryChildren += 1;
      usersWithPrimary += 1;
    } else if (totalCounts(userReferences) > 0) {
      orphanUsers += 1;
    }
    for (const key of REFERENCE_KEYS) {
      references[key] += userReferences[key];
      if (!primary.exists) orphanReferences[key] += userReferences[key];
    }
  }

  return {
    usersScanned: users.size,
    primaryChildren,
    usersWithPrimary,
    references,
    totalReferences: totalCounts(references),
    orphanUsers,
    orphanReferences,
    totalOrphanReferences: totalCounts(orphanReferences),
  };
}

async function createIfMissing(reference, data) {
  const snapshot = await reference.get();
  if (snapshot.exists) return false;
  await reference.set(data);
  return true;
}

async function copyChildSubcollection(userRef, newChildRef, name) {
  const source = await userRef
    .collection("children")
    .doc(PRIMARY_CHILD_ID)
    .collection(name)
    .get();
  let copied = 0;
  for (const document of source.docs) {
    if (await createIfMissing(newChildRef.collection(name).doc(document.id), document.data())) {
      copied += 1;
    }
  }
  return copied;
}

/**
 * Plans or applies the migration. `apply: false` is a dry run: no Firestore
 * write or mapping occurs. Re-running apply is safe and never overwrites a
 * document that already exists, so post-migration writes are preserved.
 */
export async function migratePrimaryChildren(db, { apply = false } = {}) {
  const users = await db.collection("users").get();
  const result = {
    mode: apply ? "apply" : "dry-run",
    usersScanned: users.size,
    usersWithPrimary: 0,
    migratedUsers: 0,
    plannedUsers: 0,
    alreadyMigratedUsers: 0,
    copied: emptyCounts(),
    planned: emptyCounts(),
  };

  for (const user of users.docs) {
    const userRef = db.doc(`users/${user.id}`);
    const primaryRef = userRef.collection("children").doc(PRIMARY_CHILD_ID);
    const primary = await primaryRef.get();
    if (!primary.exists) continue;

    result.usersWithPrimary += 1;
    const references = await collectUserReferences(db, user.id, true);
    for (const key of REFERENCE_KEYS) result.planned[key] += references[key];

    const mappingRef = userRef.collection("migrations").doc(MIGRATION_DOC_ID);
    const mapping = await mappingRef.get();
    const newChildId = typeof mapping.get("newChildId") === "string"
      ? mapping.get("newChildId")
      : userRef.collection("children").doc().id;
    if (mapping.get("status") === "migrated") result.alreadyMigratedUsers += 1;

    if (!apply) {
      result.plannedUsers += 1;
      continue;
    }

    if (!mapping.exists) {
      await mappingRef.set({
        schemaVersion: 1,
        flowVersion: MIGRATION_FLOW_VERSION,
        legacyId: PRIMARY_CHILD_ID,
        newChildId,
        status: "pending",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    const newChildRef = userRef.collection("children").doc(newChildId);
    if (await createIfMissing(newChildRef, primary.data() ?? {})) {
      result.copied.childProfile = (result.copied.childProfile ?? 0) + 1;
    }

    result.copied.bookmarks += await copyChildSubcollection(
      userRef, newChildRef, "bookmarks",
    );
    result.copied.dailySummaries += await copyChildSubcollection(
      userRef, newChildRef, "dailySummaries",
    );

    const sessions = await userRef.collection("sessions").get();
    const primarySessions = sessions.docs.filter((document) =>
      document.get("childId") === PRIMARY_CHILD_ID,
    );
    const sessionMap = new Map();
    for (const session of primarySessions) {
      const migratedSessionId = `migrated_${session.id}`;
      sessionMap.set(session.id, migratedSessionId);
      if (await createIfMissing(
        userRef.collection("sessions").doc(migratedSessionId),
        { ...session.data(), childId: newChildId },
      )) result.copied.sessions += 1;
    }

    const attempts = await userRef.collection("activityAttempts").get();
    for (const attempt of attempts.docs) {
      const oldSessionId = attempt.get("sessionId");
      const newSessionId = sessionMap.get(oldSessionId);
      if (!newSessionId) {
        // Orphan attempts are reported by inventory, never guessed into a
        // migrated session that does not exist.
        continue;
      }
      const suffix = typeof oldSessionId === "string" &&
        attempt.id.startsWith(`${oldSessionId}_`)
        ? attempt.id.slice(oldSessionId.length + 1)
        : attempt.id;
      if (await createIfMissing(
        userRef.collection("activityAttempts").doc(`${newSessionId}_${suffix}`),
        { ...attempt.data(), childId: newChildId, sessionId: newSessionId },
      )) result.copied.activityAttempts += 1;
    }

    const progress = await userRef.collection("learningProgress").get();
    for (const document of progress.docs.filter(hasPrimaryReference)) {
      const newId = document.id.startsWith(`${PRIMARY_CHILD_ID}_`)
        ? `${newChildId}_${document.id.slice(PRIMARY_CHILD_ID.length + 1)}`
        : `migrated_${document.id}`;
      if (await createIfMissing(
        userRef.collection("learningProgress").doc(newId),
        { ...document.data(), childId: newChildId },
      )) result.copied.learningProgress += 1;
    }

    const gamification = await userRef
      .collection("gamification")
      .doc(PRIMARY_CHILD_ID)
      .get();
    if (gamification.exists && await createIfMissing(
      userRef.collection("gamification").doc(newChildId),
      { ...gamification.data(), childId: newChildId },
    )) result.copied.gamification += 1;

    const assessment = await userRef
      .collection("assessmentResults")
      .doc(PRIMARY_CHILD_ID)
      .get();
    if (assessment.exists && await createIfMissing(
      userRef.collection("assessmentResults").doc(newChildId),
      { ...assessment.data(), childId: newChildId },
    )) result.copied.assessmentResults += 1;

    await mappingRef.set({
      schemaVersion: 1,
      flowVersion: MIGRATION_FLOW_VERSION,
      legacyId: PRIMARY_CHILD_ID,
      newChildId,
      status: "migrated",
      counts: references,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    result.migratedUsers += 1;
  }

  return result;
}

/**
 * Deletes only the migrated copies and mapping. The legacy `primary` document
 * and every legacy reference remain untouched. Post-migration writes under the
 * new child are also removed; use this before cutover or restore an export.
 */
export async function rollbackPrimaryMigration(db) {
  const users = await db.collection("users").get();
  const result = {
    usersScanned: users.size,
    rolledBackUsers: 0,
    deleted: { ...emptyCounts(), childProfile: 0, mappings: 0 },
  };

  for (const user of users.docs) {
    const userRef = db.doc(`users/${user.id}`);
    const mappingRef = userRef.collection("migrations").doc(MIGRATION_DOC_ID);
    const mapping = await mappingRef.get();
    const newChildId = mapping.get("newChildId");
    if (!mapping.exists || typeof newChildId !== "string") continue;

    const newChildRef = userRef.collection("children").doc(newChildId);
    if ((await newChildRef.get()).exists) {
      result.deleted.bookmarks += (await newChildRef.collection("bookmarks").get()).size;
      result.deleted.dailySummaries +=
        (await newChildRef.collection("dailySummaries").get()).size;
      await db.recursiveDelete(newChildRef);
      result.deleted.childProfile += 1;
    }

    const sessions = await userRef.collection("sessions").get();
    for (const session of sessions.docs.filter((document) =>
      document.get("childId") === newChildId,
    )) {
      await session.ref.delete();
      result.deleted.sessions += 1;
    }
    const attempts = await userRef.collection("activityAttempts").get();
    for (const attempt of attempts.docs.filter((document) =>
      document.get("childId") === newChildId,
    )) {
      await attempt.ref.delete();
      result.deleted.activityAttempts += 1;
    }
    const progress = await userRef.collection("learningProgress").get();
    for (const document of progress.docs.filter((entry) =>
      entry.get("childId") === newChildId ||
      entry.id.startsWith(`${newChildId}_`),
    )) {
      await document.ref.delete();
      result.deleted.learningProgress += 1;
    }
    for (const collection of ["gamification", "assessmentResults"]) {
      const reference = userRef.collection(collection).doc(newChildId);
      if ((await reference.get()).exists) {
        await reference.delete();
        result.deleted[collection] += 1;
      }
    }

    await mappingRef.delete();
    result.deleted.mappings += 1;
    result.rolledBackUsers += 1;
  }
  return result;
}
