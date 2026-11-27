import { Timestamp, Transaction } from "firebase-admin/firestore";

import { canAccessModule } from "../domain/content_access";
import {
  db,
  paths,
  PREMIUM_ENTITLEMENT_ID,
} from "../lib/firestore";

/** Reads the module and entitlement in the caller's transaction. */
export async function hasLessonAccess(
  tx: Transaction,
  uid: string,
  lesson: FirebaseFirestore.DocumentData,
): Promise<boolean> {
  if (typeof lesson.moduleId !== "string" || lesson.moduleId.length === 0) {
    return false;
  }
  const firestore = db();
  const [moduleSnap, entitlementSnap] = await Promise.all([
    tx.get(firestore.collection(paths.modules).doc(lesson.moduleId)),
    tx.get(
      firestore
        .collection(paths.entitlements(uid))
        .doc(PREMIUM_ENTITLEMENT_ID),
    ),
  ]);
  if (!moduleSnap.exists || moduleSnap.get("published") !== true) return false;

  return canAccessModule(
    moduleSnap.get("number"),
    entitlementSnapshot(entitlementSnap.data()),
    new Date(),
  );
}

/** Maps the stored entitlement document to the domain authority's shape. */
export function entitlementSnapshot(
  data: FirebaseFirestore.DocumentData | undefined,
): {
  active: unknown;
  features: unknown;
  validFrom: Date | null;
  validUntil: Date | null;
} | null {
  if (!data) return null;
  return {
    active: data.active,
    features: data.features,
    validFrom: timestampDate(data.validFrom),
    validUntil: timestampDate(data.validUntil),
  };
}

/** Reads the same entitlement authority used by lesson start. */
export async function canAccessModuleForUser(
  uid: string,
  moduleNumber: number,
): Promise<boolean> {
  const entitlement = await db()
    .collection(paths.entitlements(uid))
    .doc(PREMIUM_ENTITLEMENT_ID)
    .get();
  return canAccessModule(
    moduleNumber,
    entitlementSnapshot(entitlement.data()),
    new Date(),
  );
}

function timestampDate(value: unknown): Date | null {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}
