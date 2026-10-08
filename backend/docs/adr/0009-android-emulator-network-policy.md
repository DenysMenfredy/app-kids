# ADR 0009 — Local HTTP access for Android Firebase emulators

Date: 2026-10-08 · Status: accepted

## Context

Parent registration on an Android virtual device failed with
`Cleartext HTTP traffic to 10.0.2.2 not permitted`. The app correctly
selected the demo Firebase project and Auth emulator, but its Android
manifest had no network policy permitting the emulator's HTTP endpoint.
Android blocks cleartext traffic by default for the app's target SDK.

The app supports Firebase emulator mode in debug and profile builds and
rejects it in release. App Check remains disabled only in emulator mode
under ADR 0004; the accompanying missing-provider warning is separate
from the cleartext failure.

## Decision

- Add Android network security configurations only in the debug and
  profile source sets, referenced by their respective manifests.
- Deny cleartext traffic by default and permit it only for `10.0.2.2`
  (Android virtual device host alias), `localhost` and `127.0.0.1`
  (loopback, including USB port forwarding).
- Keep the main/release manifest free of emulator network exceptions.
  Authentication, App Check activation outside emulator mode and all
  server authorization remain unchanged.
- Document rebuilding/reinstalling the app after native policy changes
  and USB port forwarding for physical Android devices. A custom LAN host
  requires an explicit development-policy entry.

## Consequences

Local parent registration and callable requests can use Firebase's HTTP
emulators without granting every HTTP host an exception. Release builds
retain Android's default cleartext restrictions. Native manifest changes
require a full rebuild; Dart hot reload or hot restart is insufficient.

References:

- [Android network security configuration](https://developer.android.com/privacy-and-security/security-config)
- [Connecting to the Firebase Auth emulator](https://firebase.google.com/docs/emulator-suite/connect_auth)
