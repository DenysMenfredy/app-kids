/**
 * Founder pricing catalog (spec §7). BRL amounts are integer cents:
 * R$149.90 == 14990. Stripe price ids are configured per environment and
 * resolved at runtime; the plan ids here are the stable domain identifiers.
 */

export type PlanInterval = "month" | "quarter" | "year";

export interface Plan {
  readonly id: string;
  readonly amountCents: number;
  readonly currency: "BRL";
  readonly interval: PlanInterval;
}

export const PLANS: Record<string, Plan> = {
  founder_monthly: {
    id: "founder_monthly",
    amountCents: 1990,
    currency: "BRL",
    interval: "month",
  },
  founder_quarterly: {
    id: "founder_quarterly",
    amountCents: 4990,
    currency: "BRL",
    interval: "quarter",
  },
  founder_annual: {
    id: "founder_annual",
    amountCents: 14990,
    currency: "BRL",
    interval: "year",
  },
};

export function isKnownPlan(planId: string): boolean {
  return planId in PLANS;
}
