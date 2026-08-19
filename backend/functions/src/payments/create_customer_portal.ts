import { HttpsError, onCall } from "firebase-functions/v2/https";

import { checkoutReturnUrl, stripeSecretKey } from "../config";
import { db, paths } from "../lib/firestore";
import { requireAuth } from "../lib/guards";
import { log } from "../lib/logger";
import { stripeProvider } from "./stripe_provider";

/**
 * Opens the Stripe self-service billing portal (cancel, change plan,
 * update payment method). The customer id is read from the user's own
 * subscription records — never from client input.
 */
export const createCustomerPortal = onCall(
  {
    enforceAppCheck: true,
    secrets: [stripeSecretKey],
  },
  async (request) => {
    const uid = requireAuth(request);

    const subscriptions = await db()
      .collection(paths.subscriptions(uid))
      .where("provider", "==", "stripe")
      .orderBy("updatedAt", "desc")
      .limit(1)
      .get();

    const customerId = subscriptions.docs[0]?.get("providerCustomerId") as
      | string
      | undefined;
    if (!customerId) {
      throw new HttpsError(
        "failed-precondition",
        "Nenhuma assinatura encontrada.",
      );
    }

    const url = await stripeProvider.createCustomerPortalSession(
      customerId,
      `${checkoutReturnUrl.value()}/portal-return`,
    );
    log("payments", "customer_portal_created", { uid });
    return { url };
  },
);
