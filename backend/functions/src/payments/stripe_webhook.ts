import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { onRequest } from "firebase-functions/v2/https";
import Stripe from "stripe";

import { stripeSecretKey, stripeWebhookSecret } from "../config";
import { PLANS } from "../domain/plans";
import { fromStripeStatus } from "../domain/subscription";
import { db, paths } from "../lib/firestore";
import {
  claimWebhookEvent,
  completeWebhookEvent,
  releaseWebhookEvent,
} from "../lib/idempotency";
import { log, logError } from "../lib/logger";
import { stripeProvider } from "./stripe_provider";
import {
  recordStripeCustomerFromCheckout,
  resolveStripeSubscriptionOwner,
} from "./stripe_customer_mapping";
import {
  consumeTrialEligibility,
  releaseTrialReservation,
} from "./trial_eligibility";

/**
 * Stripe webhook (spec §8) — the ONLY authoritative payment signal.
 * Pipeline: verify signature → idempotency check → update subscription.
 * Entitlement sync happens via the Firestore trigger on the subscription
 * document (subscriptions/syncEntitlement), keeping this handler narrow.
 */
export const stripeWebhook = onRequest(
  { secrets: [stripeSecretKey, stripeWebhookSecret] },
  async (request, response) => {
    const signature = request.headers["stripe-signature"];
    if (typeof signature !== "string") {
      response.status(400).send("Missing signature");
      return;
    }

    let event: Stripe.Event;
    try {
      event = stripeProvider.constructWebhookEvent(
        request.rawBody,
        signature,
        stripeWebhookSecret.value(),
      );
    } catch (error) {
      logError("payments", "webhook_signature_invalid", {
        error: String(error),
      });
      response.status(400).send("Invalid signature");
      return;
    }

    // Repeated Stripe events must not cause duplicate side effects (§8).
    const claim = await claimWebhookEvent(
      db(),
      "stripe",
      event.id,
      event.type,
    );
    if (claim.status === "processed") {
      log("payments", "webhook_duplicate_skipped", {
        eventId: event.id,
        eventType: event.type,
      });
      response.status(200).send("Already processed");
      return;
    }
    if (claim.status === "in_progress") {
      response.status(503).send("Event is currently processing");
      return;
    }

    try {
      await handleEvent(event);
      const completed = await completeWebhookEvent(
        db(),
        "stripe",
        event.id,
        claim.claimToken,
      );
      if (!completed) {
        response.status(503).send("Webhook processing lease expired");
        return;
      }
      response.status(200).send("OK");
    } catch (error) {
      logError("payments", "webhook_processing_failed", {
        eventId: event.id,
        eventType: event.type,
        error: String(error),
      });
      // Surface a 500 and release only this invocation's lease, so Stripe's
      // retry can reclaim the event without racing a newer delivery.
      await releaseWebhookEvent(db(), "stripe", event.id, claim.claimToken);
      response.status(500).send("Processing failed");
    }
  },
);

async function handleEvent(event: Stripe.Event): Promise<void> {
  switch (event.type) {
    case "checkout.session.completed": {
      const session = event.data.object;
      const uid = await recordStripeCustomerFromCheckout(db(), session);
      const reservationId = session.metadata?.trialReservationId;
      if (uid && reservationId) {
        await consumeTrialEligibility(db(), uid, { reservationId });
      }
      log("payments", "checkout_completed", {
        uid: session.client_reference_id,
        sessionId: session.id,
      });
      // Subscription state arrives via customer.subscription.* events;
      // nothing entitlement-related happens here (§8: never activate
      // Premium from the checkout redirect or its completion event alone).
      break;
    }
    case "checkout.session.expired": {
      const session = event.data.object;
      const uid = session.metadata?.uid;
      const reservationId = session.metadata?.trialReservationId;
      if (uid && reservationId) {
        await releaseTrialReservation(db(), uid, reservationId);
      }
      log("payments", "checkout_expired", {
        uid,
        sessionId: session.id,
      });
      break;
    }
    case "customer.subscription.created":
    case "customer.subscription.updated":
    case "customer.subscription.deleted": {
      const eventSubscription = event.data.object;
      const subscription = await stripeProvider.retrieveSubscription(
        eventSubscription.id,
      );
      const uid = await resolveStripeSubscriptionOwner(db(), subscription);
      if (subscription.metadata?.uid && subscription.metadata.uid !== uid) {
        throw new Error(`Subscription ${subscription.id} UID metadata mismatch`);
      }
      await consumeTrialEligibility(db(), uid, {
        subscriptionId: subscription.id,
        reservationId: subscription.metadata?.trialReservationId,
      });
      await upsertSubscription(subscription, event.created, uid);
      break;
    }
    case "customer.subscription.trial_will_end": {
      const subscription = event.data.object;
      log("subscriptions", "trial_will_end", {
        subscriptionId: subscription.id,
        trialEnd: subscription.trial_end,
      });
      break;
    }
    case "invoice.paid": {
      log("payments", "invoice_paid", { invoiceId: event.data.object.id });
      break;
    }
    case "invoice.payment_failed": {
      logError("payments", "invoice_payment_failed", {
        invoiceId: event.data.object.id,
      });
      // Status transition (past_due) arrives via subscription.updated.
      break;
    }
    default:
      log("payments", "webhook_event_ignored", { eventType: event.type });
  }
}

/** Mirrors the provider subscription into users/{uid}/subscriptions. */
async function upsertSubscription(
  sub: Stripe.Subscription,
  providerEventCreated: number,
  uid: string,
): Promise<void> {
  const planId = sub.metadata?.planId ?? "unknown";
  const plan = PLANS[planId];
  const item = sub.items.data[0];

  const periodStart = item?.current_period_start ?? sub.start_date;
  const periodEnd = item?.current_period_end ?? sub.start_date;

  const subscriptionRef = db().collection(paths.subscriptions(uid)).doc(sub.id);
  const wroteCurrentState = await db().runTransaction(async (transaction) => {
    const existing = await transaction.get(subscriptionRef);
    const previousEventCreated = existing.get("providerEventCreated");
    if (
      typeof previousEventCreated === "number" &&
      previousEventCreated > providerEventCreated
    ) {
      return false;
    }
    transaction.set(
      subscriptionRef,
      {
        provider: "stripe",
        providerCustomerId:
          typeof sub.customer === "string" ? sub.customer : sub.customer.id,
        providerSubscriptionId: sub.id,
        planId,
        status: fromStripeStatus(sub.status),
        currency: "BRL",
        amountCents: plan?.amountCents ?? item?.price.unit_amount ?? 0,
        interval: plan?.interval ?? "month",
        currentPeriodStart: Timestamp.fromMillis(periodStart * 1000),
        currentPeriodEnd: Timestamp.fromMillis(periodEnd * 1000),
        trialStart: sub.trial_start
          ? Timestamp.fromMillis(sub.trial_start * 1000)
          : null,
        trialEnd: sub.trial_end
          ? Timestamp.fromMillis(sub.trial_end * 1000)
          : null,
        cancelAtPeriodEnd: sub.cancel_at_period_end,
        providerEventCreated,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return true;
  });

  if (wroteCurrentState) {
    log("subscriptions", "subscription_upserted", {
      uid,
      subscriptionId: sub.id,
      status: sub.status,
    });
  } else {
    log("subscriptions", "stale_subscription_event_ignored", {
      uid,
      subscriptionId: sub.id,
      eventCreated: providerEventCreated,
    });
  }
}
