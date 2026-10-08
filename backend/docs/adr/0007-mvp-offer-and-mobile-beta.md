# ADR 0007 — Seven-day trial, first-module free access and purchase-free mobile beta

Date: 2026-10-07 · Status: accepted for product scope; implementation partial

Owner: product owner (decision supplied during execution of the MVP plan).

## Decision

- **D01:** Implement a real seven-day trial. Eligibility is decided by the
  backend/provider, once per qualifying account. Checkout, cancellation,
  renewal and the end of trial must match the displayed offer. The trial may
  start without a payment method; Stripe cancels it at day seven if no method
  has been added. If a method is added, the checkout offer must plainly show
  the plan price, renewal interval and first charge date. Prior subscription
  history consumes trial eligibility. Until those flows and their integration
  tests exist, no checkout may be enabled.
- **D02:** The entire first introductory module is free. Later modules and
  the books advertised as Premium require a valid entitlement. Content
  access is fail-closed in Firestore Rules and lesson-session callables:
  module 1 is free; later activity/story payloads require an unexpired
  `full_curriculum` entitlement. Book pages and protected media remain open
  because the app does not yet serve a real book/Storage catalog.
- **D03:** The first Android/iOS beta has no in-app purchase path. Stripe
  Checkout is reserved for a separately configured web channel. Mobile
  commercial launch remains blocked on a current store-billing decision
  and native implementation. No client-side flag may grant Premium.

## Consequences

The mobile paywall does not launch checkout in the beta. Web checkout is
opt-in in the Flutter build and, independently, restricted by the backend
to a configured App Check web app ID; without that configuration the
callable fails closed. The server now reserves a single trial per parent,
creates a seven-day no-card Checkout trial with cancel-on-missing-payment-
method behavior, and stores server-created Checkout/customer ownership maps.
Webhook processing uses a recoverable lease, retrieves current Stripe
subscription state, and persists only after side effects complete. A
`trial_will_end` event is logged, but no user-facing email reminder is wired
yet. These code paths have not passed the required signed-webhook/Stripe
integration matrix, so T09/T11 remain partial and the web channel must stay
disabled until that validation and trial-end communication are complete.

Open product decisions D04–D07 (offline boundary, child profile/consent,
launch content manifest and retention matrix) remain explicit follow-ups.
