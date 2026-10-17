# ADR 0018 — Native Google identity and explicit provider setup

Date: 2026-10-16. Status: client implementation accepted; real provider/device
acceptance remains open. Applies to dev/staging, not production.

## Context

All four Firebase app registrations exist, but the first read of the Auth admin
API returned `CONFIGURATION_NOT_FOUND` for both projects. App registration does
not initialize Firebase Authentication or enable its providers. The documented
public `identityPlatform:initializeAuth` API requires billing; it is not a reason
to upgrade these Spark projects. The owner must initialize ordinary Firebase
Authentication through the Firebase console while signed in.

The existing Flutter Google implementation used `signInWithProvider` for every
platform. Firebase's Flutter guide instead requires the official `google_sign_in`
SDK on native platforms and a Firebase credential exchange. A provider enabled
in the console alone would not fix that client-side gap.

## Decision

- Keep Firebase Auth as the identity authority. Google native supplies an ID
  token; `signInWithCredential` determines the Firebase UID and new-user outcome.
  The web path uses Firebase's Google popup. No email-based lookup, merge,
  entitlement activation or client-side role assignment is added.
- Put the native SDK in an injectable data-layer service, not a widget. Initialize
  it lazily once, only after a Google button tap and valid public OAuth metadata.
  Explicitly clear its app session before authentication so a family device does
  not silently reuse the previous parent's Google identity. Do not revoke grants,
  request contacts/Drive access or attempt lightweight automatic authentication.
- Clear the Google app session on logout, while always signing out Firebase even
  if Google cleanup fails. Cancellation produces no Firebase login. Missing token,
  configuration and real authentication failures are distinct, safe UI failures;
  raw SDK errors and identity tokens are never logged or persisted by our code.
- Obtain the web audience and optional iOS client/reversed-client IDs from refreshed
  native Firebase downloads. Never invent OAuth client IDs or put client secrets in
  Dart defines. Validate project-number coherence, iOS URL-scheme coherence and
  reject ambiguous web audiences. Check OAuth on a Google tap, not at app startup,
  so email/password can operate while Google is still being configured.
- Enable only the requested email/password and Google methods when ordinary Auth
  is initialized. Keep passwordless email, anonymous and SMS out of this delivery.
  Preserve one-account-per-email and email-enumeration protection; ADR 0011's
  verified-email child boundary remains enforced server-side. No App Check or
  authorization relaxation is part of provider setup.
- The owner approved using the project-owner email as Google's public support
  contact. Keep it in provider/consent configuration, not a hardcoded client field.
- The owner does not yet have Apple Developer membership. Apple provider setup,
  app capabilities/signing and physical iOS acceptance are deferred, not silently
  enabled. ADR 0005's explicit UID-preserving linking policy is unchanged. Apple
  remains a launch gate for the intended iOS Google+Apple sign-in surface.

## Dependency review

Pinned official flutter.dev `google_sign_in` 7.2.0 (BSD-3-Clause). The resolved
adapters are Android 7.2.18 and iOS 6.3.8, plus the platform interface, web adapter
and Google Identity Services web bridge (six new Dart packages). The maintained
Android adapter uses Credential Manager; explicit `serverClientId` avoids adding
a Gradle auto-initialization path that would conflict with demo Firebase options.
The iOS adapter still needs its actual reversed-client callback URL scheme in the
native app; Dart initialization alone does not configure that scheme.

Android debug compilation and emulator installation/hot restart passed. The
resulting x86_64 debug APK is 124,357,361 bytes; the universal debug APK is
220,820,579 bytes. These unoptimized artifacts are not release-size estimates or
a controlled measurement of this plugin's incremental cost. Profile release size
before launch. This review is not a whole-dependency vulnerability audit.

## Validation / remaining gates

### Provider setup follow-up — 2026-10-17

The owner confirmed clicking Get started in both consoles. Read-only API checks
then confirmed `subtype: FIREBASE_AUTH`, billing disabled, no enabled federated
providers, anonymous/phone disabled, duplicate emails disabled and email-enumeration
protection enabled in both dev and staging.

The authorized email/password setup was applied and read back successfully in
both projects: `signIn.email.enabled=true`, `passwordRequired=true`,
`allowDuplicateEmails=false`, `emailPrivacyConfig.enableImprovedEmailPrivacy=true`
and `notification.defaultLocale=pt-BR`. The patch uses only these five field-mask
paths; it does not replace the whole Auth config, authorized domains, templates,
provider credentials, App Check, users or billing state. Passwordless email remains
disabled. No test identity or real email message was created.

Two explicit admin helpers in `backend/functions/scripts/` inventory settings and
apply the email-only setup. They use the owner's existing Firebase CLI credentials
in memory, have fixed dev/staging targets (no production option), print only a safe
status projection and are not deployed as Functions or run automatically in CI.

The owner then supplied refreshed Android/iOS files at the repository root. Both
are for dev; their original files remain untouched. Real public OAuth client IDs
were imported into the dev native archive, active native files and dev build
defines. Readback confirms Google's dev provider is enabled and its client ID
matches the imported web audience. Its Android certificate matches the registered
dev debug SHA-1. Staging still has no Google provider; its separate metadata and
signing configuration were not replaced with dev's. No OAuth client ID was
fabricated, and no client secret was added to public config. Apple remains deferred
as requested; billing is still disabled in both projects.

Runner now declares the actual dev iOS reversed-client callback. Android build
validation rejects a missing, ambiguous or mismatched native web audience when
Google is configured. Mac validation also checks native iOS OAuth IDs and Runner's
callback against the selected environment; staging Google will require its own
callback when configured. Pure regressions cover these checks, but this Linux host
cannot validate an iOS build or native Google return flow.

After the import, all 367 Flutter tests and whole-project static analysis passed.
An Android debug build using the real dev config passed. A fresh demo-emulator
launch had no Dart runtime errors before or after MCP hot restart. An initial
attachment to the old running instance surfaced a Riverpod/ChildProfileGate
build-time assertion; it did not reproduce after the fresh launch, and no fix for
that observation is claimed. Local
regressions cover credential exchange, Firebase new/returning outcomes,
cancellation, missing tokens/config, no client account merge, safe SDK errors,
logout cleanup failure, OAuth project/scheme validation and existing UI routing.
Google consent/account creation and Apple device readiness are not inferred from
these tests. No real Google login or email message was attempted.
Known demo-mode native FIS/App Check warnings remain; the restart is not evidence
of real Firebase authentication or remote notification delivery.

Use existing public debug certificate fingerprints only for dev. Staging requires
its own approved signing/Play certificate or flavor strategy; no private signing
key is generated, uploaded or copied into source. Dev SHA-1/SHA-256 registration
was completed with the existing debug certificate; no staging signing certificate
was added. No production provider, billing
account, backend deployment, user migration or email message is created here.

References: [Firebase Flutter federation](https://firebase.google.com/docs/auth/flutter/federated-auth),
[official Google plugin](https://pub.dev/packages/google_sign_in),
[public Auth initialization API](https://docs.cloud.google.com/identity-platform/docs/reference/rest/v2/projects.identityPlatform/initializeAuth).
