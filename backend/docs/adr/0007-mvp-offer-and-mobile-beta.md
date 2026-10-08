# ADR 0007 — Seven-day trial, first-module free access and purchase-free mobile beta

Date: 2026-10-07 · Status: accepted for product scope; implementation partial

Owner: product owner (decision supplied during execution of the MVP plan).

## Decision

- **D01:** Implement a real seven-day trial. Eligibility is decided by the
  backend/provider, once per qualifying account. Checkout, cancellation,
  renewal and the end of trial must match the displayed offer. Until those
  flows and their integration tests exist, no checkout may be enabled.
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
callable fails closed. The beta shows no active seven-day trial CTA while
the trial is not implemented. The existing Stripe function does **not** yet
create a trial subscription; T09/T11 remain required before enabling the
web channel. A configuration value is not a substitute for those tests.

Open product decisions D04–D07 (offline boundary, child profile/consent,
launch content manifest and retention matrix) remain explicit follow-ups.
