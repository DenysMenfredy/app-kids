import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  checkoutReturnUrl,
  stripeSecretKey,
  stripeWebCheckoutAppId,
} from "../config";
import { isKnownPlan } from "../domain/plans";
import { db, paths } from "../lib/firestore";
import { enforceAppCheck, requireAuth, requireString } from "../lib/guards";
import { log, logError } from "../lib/logger";
import { isApprovedWebCheckoutApp } from "./checkout_channel";
import { stripeProvider } from "./stripe_provider";
import { recordCheckoutSession } from "./stripe_customer_mapping";
import {
  claimTrialForCheckout,
  consumeTrialEligibility,
  refreshTrialReservation,
  releaseTrialReservation,
} from "./trial_eligibility";

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
    const allowedAppId = stripeWebCheckoutAppId.value();
    if (!isApprovedWebCheckoutApp(allowedAppId, request.app?.appId)) {
      throw new HttpsError(
        "permission-denied",
        "Checkout indisponível neste aplicativo.",
      );
    }
    const planId = requireString(request.data?.planId, "planId", {
      maxLength: 64,
    });
    if (!isKnownPlan(planId)) {
      throw new HttpsError("invalid-argument", "Plano desconhecido.");
    }

    let trialClaim = await claimTrialForCheckout(db(), uid);
    if (trialClaim.status === "reservation_needs_reconciliation") {
      const existingSession = await stripeProvider.retrieveCheckoutSession(
        trialClaim.sessionId,
      );
      if (existingSession.status === "complete") {
        await consumeTrialEligibility(db(), uid, {
          reservationId: trialClaim.reservationId,
        });
        throw new HttpsError(
          "failed-precondition",
          "Sua assinatura está sendo confirmada. Atualize o plano em instantes.",
        );
      }
      if (existingSession.status === "open") {
        if (existingSession.expires_at * 1000 <= Date.now()) {
          await stripeProvider.expireCheckoutSession(existingSession.id);
          await releaseTrialReservation(
            db(),
            uid,
            trialClaim.reservationId,
          );
          trialClaim = await claimTrialForCheckout(db(), uid);
        } else {
          await refreshTrialReservation(
            db(),
            uid,
            trialClaim.reservationId,
            existingSession.id,
            existingSession.expires_at,
          );
          throw new HttpsError(
            "failed-precondition",
            "Já existe uma tentativa de assinatura em andamento.",
          );
        }
      } else {
        await releaseTrialReservation(db(), uid, trialClaim.reservationId);
        trialClaim = await claimTrialForCheckout(db(), uid);
      }
    }
    if (trialClaim.status === "subscription_exists") {
      throw new HttpsError(
        "failed-precondition",
        "Sua conta já possui uma assinatura. Acesse o gerenciamento do plano.",
      );
    }
    if (trialClaim.status === "checkout_in_progress") {
      throw new HttpsError(
        "failed-precondition",
        "Já existe uma tentativa de assinatura em andamento.",
      );
    }
    if (trialClaim.status === "reservation_needs_reconciliation") {
      throw new HttpsError(
        "failed-precondition",
        "Já existe uma tentativa de assinatura em andamento.",
      );
    }
    const trialReservationId =
      trialClaim.status === "reserved" ? trialClaim.reservationId : undefined;

    let session:
      | Awaited<ReturnType<typeof stripeProvider.createCheckoutSession>>
      | undefined;
    try {
      const userSnap = await db().doc(paths.user(uid)).get();
      const email = userSnap.get("email") as string | undefined;
      const base = checkoutReturnUrl.value();
      session = await stripeProvider.createCheckoutSession({
        uid,
        email,
        planId,
        trialReservationId,
        successUrl: `${base}/success?session_id={CHECKOUT_SESSION_ID}`,
        cancelUrl: `${base}/cancel`,
      });
      await recordCheckoutSession(db(), {
        uid,
        planId,
        sessionId: session.id,
        expiresAt: session.expiresAt,
        trialReservationId,
      });
      log("payments", "checkout_session_created", {
        uid,
        planId,
        includesTrial: Boolean(trialReservationId),
      });
      return { url: session.url };
    } catch (error) {
      if (session) {
        try {
          await stripeProvider.expireCheckoutSession(session.id);
        } catch (expireError) {
          logError("payments", "orphan_checkout_expiration_failed", {
            uid,
            sessionId: session.id,
            error: String(expireError),
          });
        }
      }
      if (trialReservationId) {
        try {
          await releaseTrialReservation(db(), uid, trialReservationId);
        } catch (releaseError) {
          logError("payments", "trial_reservation_release_failed", {
            uid,
            error: String(releaseError),
          });
        }
      }
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
