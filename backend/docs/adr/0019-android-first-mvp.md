# ADR 0019 — Android-first MVP (Google Play only)

Date: 2026-11-27. Status: accepted by the founder. Supersedes the iOS scope of
ADR 0017 for the MVP gates G1–G3; the store-only decision remains, and the App
Store path is deferred, not cancelled.

## Context

The MVP was planned for Android and iOS, but iOS has never compiled on this
project, there is no Apple Developer membership and no Mac available. G1–G3
would otherwise wait on accounts and hardware that do not exist, while Android
already has a working build, Firebase registrations and a Play Billing plugin
spike. The founder confirmed Android-only for the current MVP.

## Decision

- The MVP ships on Android only, distributed through Google Play, starting with
  internal testing.
- G3 means commercial launch on Google Play with Google Play Billing. The App
  Store is out of G1–G3.
- No iOS task, Mac, Apple Developer membership, App Store Connect, Sign in with
  Apple or App Store Server API is required for G1–G3. No gate is blocked on
  them.
- Keep the iOS project in the repository and preserve portability. Do not add an
  Android-only data model, platform-specific entitlement ownership or a server
  contract that would force rework when iOS returns. Keep the billing provider
  abstraction and the existing StoreKit adapter code compiling where practical.
- Billing implementation is Android-only for now: Play Developer API
  verification, RTDN/Pub/Sub, server acknowledgement, restore, cancellation and
  refund handling. The client remains untrusted.
- Store work covers Play Console, internal testing, app signing, Data Safety,
  age rating, privacy policy and the families/children audience requirements.
- Cross-platform entitlement stays UID-wide in the data model (D08) even though
  only Android can acquire during the MVP. Do not encode a store-specific owner
  in Firestore.

## iOS reentry criteria

iOS returns only through a new ADR that re-enables it in a gate, after:

1. Apple Developer Program membership and a Mac with Xcode able to build the
   pinned Flutter version.
2. App Store Connect products for the same monthly/quarterly/annual benefit.
3. App Store Server API and Notifications V2 credentials, plus a sandbox test
   account.
4. A plan and estimates for native compilation, signing, review and physical
   device validation.

## Consequences

- G1/G2 estimates lose the Apple/Mac dependency; G3 is Android-only.
- The iOS path is explicitly future work, not "done". Gate reports must not
  claim iOS validation.
- Android shortcuts that break portability are rejected in review; this ADR is
  the reference for that decision.
