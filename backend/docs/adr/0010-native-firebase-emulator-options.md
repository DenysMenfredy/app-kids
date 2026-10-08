# ADR 0010 — Firebase emulator options accepted by native SDKs

Date: 2026-10-08 · Status: accepted

## Context

The Android app could register a parent with the Auth emulator but could
not save a child through the Functions SDK. The native call threw
`IllegalArgumentException: Please set a valid API key` before sending an
HTTP request. The original `demo-api-key` placeholder did not meet Firebase
Installations' API-key format check. REST smoke tests did not exercise this
native initialization path.

The App Check missing-provider warning appeared alongside this failure,
but attestation enforcement is already scoped by ADR 0004. It was not the
exception blocking this Android request.

## Decision

- Use a deliberately fake API key with the native SDK's required format
  (`A` followed by 38 word/hyphen characters) only in `demoFirebaseOptions`.
- Retain the existing demo project and app ID. No real project credentials
  are introduced, and retaining the app ID preserves local Auth storage.
- Keep production Firebase options, release emulator rejection, App Check
  enforcement and server-side parent/child authorization unchanged.
- Log caught profile-save exceptions and stack traces only in debug builds;
  parent-facing UI must not display native configuration or credential data.
- Give the error snackbar a retry action because it overlaps the fixed
  continue button; retries retain the input and logical request ID.
- Add a syntax regression test and a save/retry widget test, and verify the
  native Android save flow. Changes to initialized native options require
  restarting the application process, rather than only Dart hot reload.

## Consequences

The demo client can obtain the local installation ID needed by the native
Functions SDK without failing its initialization preconditions. The key is
a format-valid placeholder, not a usable Google API credential. Tests must
cover the native client boundary as well as the backend REST flow.

References:

- [Firebase initialization options](https://firebase.google.com/support/guides/init-options)
- [Firebase Installations format checks](https://github.com/firebase/firebase-android-sdk/blob/master/firebase-installations/src/main/java/com/google/firebase/installations/Utils.java)
