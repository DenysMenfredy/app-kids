import { HttpsError, onCall } from "firebase-functions/v2/https";
import { enforceAppCheck, requireAuth } from "../lib/guards";

/** Keep the old URL fail-closed for installed clients; do not create charges.
 * Legacy webhook/portal reconciliation remains until a customer inventory and
 * native-store staging validation authorize its controlled retirement.
 */
export const createCheckoutSession = onCall({ enforceAppCheck }, async (request) => {
  requireAuth(request);
  throw new HttpsError("failed-precondition",
    "Novas assinaturas estão disponíveis somente pelas lojas Google Play e App Store, quando habilitadas no app.");
});
