# ADR 0004 — App Check enforcement stops at the emulator

Date: 2026-09-12 · Status: accepted

## Context

Every callable declares `enforceAppCheck: true` (spec §12: App Check is an
app-integrity layer in addition to Auth). Running the backend locally
surfaced two consequences of that.

First, the Functions emulator *does* enforce App Check. It accepts any token
value without verifying it, but rejects a request that carries no
`X-Firebase-AppCheck` header at all — with `UNAUTHENTICATED`, which reads
like an auth failure and is easy to misdiagnose. The emulator has no app
binary to attest and no App Check backend to issue tokens, so nothing local
can produce that header.

Second, and more importantly: **the Flutter app has no App Check
integration**. It never sends the header, so the same rejection would happen
against a real project, not just the emulator.

## Decision

1. Enforcement is derived rather than hardcoded:
   `export const enforceAppCheck = process.env.FUNCTIONS_EMULATOR !== "true"`.
   Deployed environments keep full enforcement; the emulator, where
   attestation is meaningless, skips it. Authentication and role checks are
   untouched in both cases — App Check attests the caller's *binary*, not
   the caller's *identity*, so this never widens who may do what.
2. The app's missing App Check integration is recorded as a release blocker
   rather than worked around. Before any deployment that real devices talk
   to, the app must add `firebase_app_check` and activate a provider (Play
   Integrity on Android, App Attest on iOS, reCAPTCHA on web), with debug
   providers registered for development builds.

## Consequences

- Local development works on every target with no App Check setup.
- The production gap is now explicit. Deploying the current app against a
  real project would fail every callable with `UNAUTHENTICATED`; the MVP
  acceptance criteria's "App Check enforcement" item is not met until the
  client side lands.
- `backend/smoke.sh` exercises the callables end to end against the
  emulator, so the auth and reward paths stay covered despite the exemption.
