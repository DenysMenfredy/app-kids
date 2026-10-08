# ADR 0011 — Email verification before child setup and checkout

Date: 2026-10-08 · Status: accepted; implementation locally complete, integration validation open

## Context

Email/password registration previously moved directly to child-profile setup.
An unverified address could therefore create child data and, when checkout is
enabled, attempt to begin a paid subscription. The product owner chose to
require confirmation for email/password accounts before those operations,
while Google and Apple sign-ins should continue without an extra step.

## Decision

- Email/password users may sign in and use existing app surfaces, but must
  confirm the address before creating or editing a child profile or beginning
  checkout. The UI explains the gate and supports resending the Firebase Auth
  confirmation message with a cooldown.
- Firebase Auth's email-verification status is refreshed before continuing;
  the app also forces an ID-token refresh so Cloud Functions receive the
  current `email_verified` claim.
- The router directs unverified users to confirmation when they reach child
  setup. Firestore Rules reject direct child-profile edits without verification,
  and the `createChildProfile` and `createCheckoutSession` callables validate
  the authenticated token server-side.
- Google and Apple sign-ins do not get a second confirmation step. There is no
  automatic account merge based on an email address; Apple linking behavior
  remains governed by ADR 0005.
- Existing app access and sign-in are not globally blocked. Verification is a
  prerequisite only at the child-profile and checkout boundaries.

## Consequences and validation gates

Unverified accounts can no longer use stale client state or direct callable
requests to create child profiles or checkout sessions. A parent can finish
verification in an external mail app and return to the app to refresh status.
Firebase Auth emulator delivery, provider claims, rules tests, and real-device
mail-link behavior must be validated in the configured staging project before
release.
