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

  const entitlement = entitlementSnap.data();
  return canAccessModule(
    moduleSnap.get("number"),
    entitlement
      ? {
          active: entitlement.active,
          features: entitlement.features,
          validFrom: timestampDate(entitlement.validFrom),
          validUntil: timestampDate(entitlement.validUntil),
        }
      : null,
    new Date(),
  );
}

function timestampDate(value: unknown): Date | null {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  return null;
}
