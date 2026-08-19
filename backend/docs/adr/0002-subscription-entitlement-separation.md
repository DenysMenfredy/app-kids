# ADR 0002 — Subscription ≠ entitlement; webhook is the payment authority

Date: 2026-08-18 · Status: accepted

## Context

Premium access must survive a future migration to Apple/Google native
billing, must never be activatable by the client, and must fail safely
when payment state is unclear (spec §7–§9).

## Decision

1. **Two documents, one direction.** `users/{uid}/subscriptions/*` mirrors
   the commercial relationship per provider; `users/{uid}/entitlements/premium`
   is the only authorization source the app reads. Entitlement is derived
   from subscriptions exclusively by the `syncEntitlement` Firestore
   trigger — a single writer.
2. **The verified Stripe webhook is the only authoritative payment
   signal.** The checkout redirect never activates anything. Webhook
   handling is idempotent via the `webhookEvents` ledger.
3. **Provider abstraction.** `PaymentProvider` (Stripe today) keeps
   checkout/portal creation behind an interface so App Store / Play
   Billing implementations can be added without touching the
   subscription or entitlement domain.

## Consequences

- Client code (and Security Rules) treat subscription/entitlement
  collections as read-only.
- Grace periods (`past_due`) and post-cancellation access are policy in
  `deriveEntitlement`, unit-tested in isolation.
- Native store billing later = new provider implementation + new webhook
  source writing the same subscription schema; entitlement logic is
  untouched.
