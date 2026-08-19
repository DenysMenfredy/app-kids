import Stripe from "stripe";

import {
  stripePriceFounderAnnual,
  stripePriceFounderMonthly,
  stripePriceFounderQuarterly,
  stripeSecretKey,
} from "../config";
import { isKnownPlan } from "../domain/plans";
import { CheckoutSessionRequest, PaymentProvider } from "./provider";

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

  async createCheckoutSession(request: CheckoutSessionRequest): Promise<string> {
    if (!isKnownPlan(request.planId)) {
      throw new Error(`Unknown plan: ${request.planId}`);
    }
    const session = await this.stripe.checkout.sessions.create({
      mode: "subscription",
      line_items: [{ price: this.priceIdFor(request.planId), quantity: 1 }],
      customer_email: request.email,
      success_url: request.successUrl,
      cancel_url: request.cancelUrl,
      // uid travels in metadata so the webhook can attribute the payment
      // without trusting anything the client sent at redirect time.
      client_reference_id: request.uid,
      subscription_data: {
        metadata: { uid: request.uid, planId: request.planId },
      },
      metadata: { uid: request.uid, planId: request.planId },
    });
    if (!session.url) {
      throw new Error("Stripe returned a session without a URL");
    }
    return session.url;
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
