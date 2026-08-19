/**
 * Subscription domain model (spec §7, §9).
 *
 * A subscription is the commercial/payment relationship with a provider.
 * It is deliberately provider-agnostic: Stripe today, App Store / Google
 * Play later. It is NOT the authorization to use Premium — that is the
 * entitlement (see entitlement.ts).
 */

export type PaymentProviderId = "stripe" | "apple_app_store" | "google_play";

export type SubscriptionStatus =
  | "active"
  | "trialing"
  | "past_due"
  | "canceled"
  | "expired";

export interface Subscription {
  provider: PaymentProviderId;
  providerCustomerId: string;
  providerSubscriptionId: string;
  planId: string;
  status: SubscriptionStatus;
  currency: "BRL";
  amountCents: number;
  interval: "month" | "quarter" | "year";
  currentPeriodStart: Date;
  currentPeriodEnd: Date;
  cancelAtPeriodEnd: boolean;
}

/**
 * Maps a Stripe subscription status onto the domain status. Unknown or
 * terminal-failure statuses map to "expired" so entitlement derivation
 * fails safely (spec §20: premium authorization fails safely).
 */
export function fromStripeStatus(stripeStatus: string): SubscriptionStatus {
  switch (stripeStatus) {
    case "active":
      return "active";
    case "trialing":
      return "trialing";
    case "past_due":
      return "past_due";
    case "canceled":
      return "canceled";
    case "incomplete":
    case "incomplete_expired":
    case "unpaid":
    case "paused":
      return "expired";
    default:
      return "expired";
  }
}
