import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { onRequest } from "firebase-functions/v2/https";
import Stripe from "stripe";

import { stripeSecretKey, stripeWebhookSecret } from "../config";
import { PLANS } from "../domain/plans";
import { fromStripeStatus } from "../domain/subscription";
import { db, paths } from "../lib/firestore";
import { claimWebhookEvent } from "../lib/idempotency";
import { log, logError } from "../lib/logger";
import { stripeProvider } from "./stripe_provider";

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
    const firstDelivery = await claimWebhookEvent(
      db(),
      "stripe",
      event.id,
      event.type,
    );
    if (!firstDelivery) {
      log("payments", "webhook_duplicate_skipped", {
        eventId: event.id,
        eventType: event.type,
      });
      response.status(200).send("Already processed");
      return;
    }

    try {
      await handleEvent(event);
      response.status(200).send("OK");
    } catch (error) {
      logError("payments", "webhook_processing_failed", {
        eventId: event.id,
        eventType: event.type,
        error: String(error),
      });
      // Surface a 500 so Stripe retries; the idempotency doc is released
      // by marking it unprocessed for the retry to pass the claim again.
      await db()
        .collection(paths.webhookEvents)
        .doc(`stripe_${event.id}`)
        .set({ processed: false }, { merge: true });
      response.status(500).send("Processing failed");
    }
  },
);

async function handleEvent(event: Stripe.Event): Promise<void> {
  switch (event.type) {
    case "checkout.session.completed": {
      const session = event.data.object;
      log("payments", "checkout_completed", {
        uid: session.client_reference_id,
        sessionId: session.id,
      });
      // Subscription state arrives via customer.subscription.* events;
      // nothing entitlement-related happens here (§8: never activate
      // Premium from the checkout redirect or its completion event alone).
      break;
    }
    case "customer.subscription.created":
    case "customer.subscription.updated":
    case "customer.subscription.deleted": {
      await upsertSubscription(event.data.object);
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
async function upsertSubscription(sub: Stripe.Subscription): Promise<void> {
  const uid = sub.metadata?.uid;
  if (!uid) {
    throw new Error(`Subscription ${sub.id} has no uid metadata`);
  }
  const planId = sub.metadata?.planId ?? "unknown";
  const plan = PLANS[planId];
  const item = sub.items.data[0];

  const periodStart = item?.current_period_start ?? sub.start_date;
  const periodEnd = item?.current_period_end ?? sub.start_date;

  await db()
    .collection(paths.subscriptions(uid))
    .doc(sub.id)
    .set(
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
        cancelAtPeriodEnd: sub.cancel_at_period_end,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  log("subscriptions", "subscription_upserted", {
    uid,
    subscriptionId: sub.id,
    status: sub.status,
  });
}
