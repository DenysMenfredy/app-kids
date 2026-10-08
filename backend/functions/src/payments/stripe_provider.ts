import Stripe from "stripe";

import {
  stripePriceFounderAnnual,
  stripePriceFounderMonthly,
  stripePriceFounderQuarterly,
  stripeSecretKey,
} from "../config";
import { isKnownPlan } from "../domain/plans";
import {
  CheckoutSession,
  CheckoutSessionRequest,
  PaymentProvider,
} from "./provider";
import { TRIAL_DURATION_DAYS } from "./trial_eligibility";

/** Stripe Checkout hosted page — no card details ever touch the app (§8). */
export class StripeProvider implements PaymentProvider {
  readonly id = "stripe" as const;

  private stripeClient: Stripe | undefined;

  private get stripe(): Stripe {
    this.stripeClient ??= new Stripe(stripeSecretKey.value());
    return this.stripeClient;
  }

  /** Maps stable domain plan ids to environment-specific Stripe price ids. */
  private priceIdFor(planId: string): string {
    switch (planId) {
      case "founder_monthly":
        return stripePriceFounderMonthly.value();
      case "founder_quarterly":
        return stripePriceFounderQuarterly.value();
      case "founder_annual":
        return stripePriceFounderAnnual.value();
      default:
        throw new Error(`Unknown plan: ${planId}`);
    }
  }

  async createCheckoutSession(
    request: CheckoutSessionRequest,
  ): Promise<CheckoutSession> {
    if (!isKnownPlan(request.planId)) {
      throw new Error(`Unknown plan: ${request.planId}`);
    }
    const session = await this.stripe.checkout.sessions.create({
      mode: "subscription",
      line_items: [{ price: this.priceIdFor(request.planId), quantity: 1 }],
      customer_email: request.email,
      ...(request.trialReservationId
        ? { payment_method_collection: "if_required" as const }
        : {}),
      success_url: request.successUrl,
      cancel_url: request.cancelUrl,
      // uid travels in metadata so the webhook can attribute the payment
      // without trusting anything the client sent at redirect time.
      client_reference_id: request.uid,
      subscription_data: {
        metadata: {
          uid: request.uid,
          planId: request.planId,
          ...(request.trialReservationId
            ? { trialReservationId: request.trialReservationId }
            : {}),
        },
        ...(request.trialReservationId
          ? {
              trial_period_days: TRIAL_DURATION_DAYS,
              trial_settings: {
                end_behavior: { missing_payment_method: "cancel" as const },
              },
            }
          : {}),
      },
      metadata: {
        uid: request.uid,
        planId: request.planId,
        ...(request.trialReservationId
          ? { trialReservationId: request.trialReservationId }
          : {}),
      },
    });
    if (!session.url || !session.expires_at) {
      throw new Error("Stripe returned a session without a URL");
    }
    return { id: session.id, url: session.url, expiresAt: session.expires_at };
  }

  /** Closes an orphaned session if persisting its id in Firestore fails. */
  async expireCheckoutSession(sessionId: string): Promise<void> {
    await this.stripe.checkout.sessions.expire(sessionId);
  }

  async retrieveCheckoutSession(
    sessionId: string,
  ): Promise<Stripe.Checkout.Session> {
    return this.stripe.checkout.sessions.retrieve(sessionId);
  }

  /** Reads Stripe's current state so delayed webhook snapshots cannot rewind it. */
  async retrieveSubscription(
    subscriptionId: string,
  ): Promise<Stripe.Subscription> {
    return this.stripe.subscriptions.retrieve(subscriptionId);
  }

  async createCustomerPortalSession(
    providerCustomerId: string,
    returnUrl: string,
  ): Promise<string> {
    const session = await this.stripe.billingPortal.sessions.create({
      customer: providerCustomerId,
      return_url: returnUrl,
    });
    return session.url;
  }

  /** Verifies the webhook signature and returns the trusted event (§8). */
  constructWebhookEvent(
    rawBody: Buffer,
    signature: string,
    webhookSecret: string,
  ): Stripe.Event {
    return this.stripe.webhooks.constructEvent(
      rawBody,
      signature,
      webhookSecret,
    );
  }
}

export const stripeProvider = new StripeProvider();
