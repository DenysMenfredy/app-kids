import { requireCurrentParentConsent } from "./consent";
import { requireNoPendingDeletion } from "./deletion";

/**
 * Single gate for callables that create or collect child data.
 *
 * A deletion tombstone wins over consent: once deletion is requested, the
 * account is closed to new child data even if the old consent is still
 * current. Consent is checked next so a missing/outdated record keeps its
 * existing typed error.
 */
export async function requireParentCanCollectChildData(uid: string): Promise<void> {
  await requireNoPendingDeletion(uid);
  await requireCurrentParentConsent(uid);
}
