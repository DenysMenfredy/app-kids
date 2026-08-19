import { Subscription, SubscriptionStatus } from "./subscription";

/**
 * Entitlement domain model (spec §7): the authorization to access Premium
 * features. Derived from subscription state by trusted backend code only.
 * Subscription ≠ entitlement — this indirection is what lets us swap or
 * mix payment providers without touching authorization.
 */

export const PREMIUM_FEATURES = [
  "full_curriculum",
  "premium_books",
  "progress_reports",
] as const;

export interface Entitlement {
  active: boolean;
  source: Subscription["provider"] | "none";
  plan: string | null;
  features: string[];
  validFrom: Date | null;
  validUntil: Date | null;
}

/** Statuses that grant access. `past_due` keeps access until period end
 *  (grace period); `canceled` keeps access until the paid period expires. */
const GRANTING_STATUSES: readonly SubscriptionStatus[] = [
  "active",
  "trialing",
  "past_due",
  "canceled",
];

/**
 * Pure derivation of the entitlement from a subscription snapshot.
 * `now` is injected for testability; production callers pass the server time.
 */
export function deriveEntitlement(
  subscription: Subscription | null,
  now: Date,
): Entitlement {
  if (
    subscription &&
    GRANTING_STATUSES.includes(subscription.status) &&
    subscription.currentPeriodEnd.getTime() > now.getTime()
  ) {
    return {
      active: true,
      source: subscription.provider,
      plan: subscription.planId,
      features: [...PREMIUM_FEATURES],
      validFrom: subscription.currentPeriodStart,
      validUntil: subscription.currentPeriodEnd,
    };
  }
  return {
    active: false,
    source: "none",
    plan: null,
    features: [],
    validFrom: null,
    validUntil: null,
  };
}
