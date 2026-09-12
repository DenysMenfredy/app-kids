import { HttpsError, onCall } from "firebase-functions/v2/https";

import { checkoutReturnUrl, stripeSecretKey } from "../config";
import { isKnownPlan } from "../domain/plans";
import { db, paths } from "../lib/firestore";
import { enforceAppCheck, requireAuth, requireString } from "../lib/guards";
import { log, logError } from "../lib/logger";
import { stripeProvider } from "./stripe_provider";

/**
 * Creates a Stripe Checkout session for the authenticated parent
 * (spec §8, §16: checkout creation is backend-only). The client receives a
 * redirect URL and nothing else; Premium is activated later by the verified
 * webhook, never by the checkout redirect.
 */
export const createCheckoutSession = onCall(
  {
    enforceAppCheck,
    secrets: [stripeSecretKey],
  },
  async (request) => {
    const uid = requireAuth(request);
    const planId = requireString(request.data?.planId, "planId", {
      maxLength: 64,
    });
    if (!isKnownPlan(planId)) {
      throw new HttpsError("invalid-argument", "Plano desconhecido.");
    }

    const userSnap = await db().doc(paths.user(uid)).get();
    const email = userSnap.get("email") as string | undefined;

    const base = checkoutReturnUrl.value();
    try {
      const url = await stripeProvider.createCheckoutSession({
        uid,
        email,
        planId,
        successUrl: `${base}/success?session_id={CHECKOUT_SESSION_ID}`,
        cancelUrl: `${base}/cancel`,
      });
      log("payments", "checkout_session_created", { uid, planId });
      return { url };
    } catch (error) {
      logError("payments", "checkout_session_failed", {
        uid,
        planId,
        error: String(error),
      });
      throw new HttpsError(
        "internal",
        "Não foi possível iniciar o pagamento. Tente novamente.",
      );
    }
  },
);
