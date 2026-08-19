import { defineSecret, defineString } from "firebase-functions/params";

/**
 * Secrets live in Secret Manager (spec §12) — never in source or app code.
 * Set per environment:
 *   firebase functions:secrets:set STRIPE_SECRET_KEY --project dev
 *   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET --project dev
 */
export const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");
export const stripeWebhookSecret = defineSecret("STRIPE_WEBHOOK_SECRET");

/**
 * Environment-scoped (non-secret) configuration. Each Firebase project
 * (letrando-dev / -staging / -production) carries its own values, so test
 * and production Stripe data never mix (spec §21).
 */
export const stripePriceFounderMonthly = defineString(
  "STRIPE_PRICE_FOUNDER_MONTHLY",
);
export const stripePriceFounderQuarterly = defineString(
  "STRIPE_PRICE_FOUNDER_QUARTERLY",
);
export const stripePriceFounderAnnual = defineString(
  "STRIPE_PRICE_FOUNDER_ANNUAL",
);

/** Base URL the checkout redirects back to (deep link into the app). */
export const checkoutReturnUrl = defineString("CHECKOUT_RETURN_URL", {
  default: "https://letrando.app/checkout",
});
