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

At the time of this decision the Flutter app had no App Check integration.
The client integration was added on 2026-10-07; physical-device attestation
and Firebase console registration remain unverified.

## Decision

1. Enforcement is derived rather than hardcoded:
   `export const enforceAppCheck = process.env.FUNCTIONS_EMULATOR !== "true"`.
   Deployed environments keep full enforcement; the emulator, where
   attestation is meaningless, skips it. Authentication and role checks are
   untouched in both cases — App Check attests the caller's *binary*, not
   the caller's *identity*, so this never widens who may do what.
2. The app activates `firebase_app_check` after Firebase initialization and
   before protected calls, with Play Integrity on Android, App Attest with
   DeviceCheck fallback on iOS and a configured reCAPTCHA site key on web.
   Debug providers are used only in debug builds; emulator mode skips
   activation because the Functions emulator skips enforcement. Release
   builds reject emulator mode.

## Consequences

- Local development works on every target with no App Check setup.
- App registration, release attestation, rejection tests and monitoring in
  dev/staging/production must still be validated before the MVP acceptance
  criterion is marked complete. A configured provider in code alone does
  not prove that a real device receives a valid token.
- `backend/smoke.sh` exercises the callables end to end against the
  emulator, so the auth and reward paths stay covered despite the exemption.
