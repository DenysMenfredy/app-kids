# Auth providers — dev and staging

Provider setup is separate from app registration and backend deployment. The
owner approved email/password and Google setup, using the Firebase project-owner
email as Google's support contact. Apple is deferred: no Developer membership yet.
Never send passwords, Apple private keys, service-account JSON or OAuth client
secrets through chat or commit them to app config.

## 1. Initialize ordinary Firebase Authentication

Sign in as the project owner in the browser and open each project's page:

- [dev Auth](https://console.firebase.google.com/project/letrando-dev/authentication/providers)
- [staging Auth](https://console.firebase.google.com/project/letrando-staging/authentication/providers)

Click **Get started** if shown. Use standard Firebase Authentication; do not link
billing or choose an Identity Platform upgrade to work around a setup error.
The first admin-API checks returned `404 CONFIGURATION_NOT_FOUND` in both projects.
CLI sign-in and Firebase app registration do not perform this console step.

**Verified 2026-10-17:** the owner completed Get started in both projects. The
admin API now returns standard `FIREBASE_AUTH`; billing is disabled in both.

## 2. Email/password

Enable **Email/Password**, leaving passwordless email-link sign-in disabled.
Keep one account per email and email-enumeration protection enabled. Do not enable
anonymous or phone sign-in. The app already supports signup, sign-in, verification
resend/check and password reset through Firebase Auth (no SMTP SDK in the app).

Prefer pt-BR as the notification/template locale. Use Firebase's default email
sender initially; a custom sender/domain requires its own verified DNS setup.
No real mailbox delivery is claimed until tested with the owner's chosen address.
Email/password accounts must verify before child setup; this remains enforced in
Rules/callables as well as routing (ADR 0011). Do not disable those checks for a demo.

**Applied and read back 2026-10-17:** email/password is enabled in dev and staging,
passwordless email is disabled, duplicate emails are disabled, email-enumeration
protection is enabled, and the default notification locale is `pt-BR`. This did not
deploy the child-profile rules/functions; that staging release gate remains open.
Anonymous/phone methods, domains and SMTP settings were not changed. No real inbox
message or test identity was created.

Read-only inventory and the explicit, repeatable email-only setup command:

```sh
cd backend
nvm use
node functions/scripts/auth_provider_status.mjs
# Remote write: fixed dev/staging targets, email-only narrow field-mask update.
node functions/scripts/configure_auth_email.mjs --apply
```

These are owner-run admin helpers, not deployed Cloud Functions or CI jobs. They
use existing CLI authentication in memory and do not print config bodies/secrets.
After this setup, all 365 Flutter and 104 Functions tests passed again on
2026-10-17; static analysis and the admin scripts' syntax checks were clean.

## 3. Google

Enable the **Google** provider in each console. Select the project-owner email as
the public support contact, as approved by the owner. Save the provider so Firebase
can create its corresponding OAuth configuration. If consent setup asks for a
privacy policy, audience, test users, publishing or verification, finish those
deliberately; do not invent URLs or publish a production consent application.

Both Android packages and iOS bundles currently equal `br.com.lele.lele`. For local
Android dev the existing debug certificate has these **public** fingerprints:

```text
SHA-1:   2E:CA:C7:F3:2D:02:F3:B7:FD:54:85:23:BB:8A:C1:4E:87:76:64:66
SHA-256: 50:73:83:FA:63:CE:90:68:62:21:E8:9F:D0:D7:A5:82:0A:60:DA:AF:EA:9B:13:C7:38:91:1C:F1:08:66:F5:5A
```

Both fingerprints above were registered in the **dev** app and read back through
Firebase's Management API. No staging fingerprint was added.

Keep debug registration in dev only. Confirm staging's signing/Play certificates
and flavor plan separately; do not treat the debug certificate as a production
certificate. Other developers' debug keystores can have different fingerprints.
Google requires a unique package/SHA-1 pair across OAuth projects, so copying
dev's pair into staging can conflict. Use distinct approved signing or flavors,
not deletion of an existing OAuth registration. See
[Firebase's explanation](https://support.google.com/firebase/answer/6401008).

Download **fresh** `google-services.json` and `GoogleService-Info.plist` after
enabling Google. Registration-only downloads have no Google OAuth clients.
The offline generator now copies the actual web OAuth audience into
`GOOGLE_WEB_CLIENT_ID` and the iOS client/scheme into `GOOGLE_IOS_CLIENT_ID` and
`GOOGLE_IOS_REVERSED_CLIENT_ID`, when present. Never use the Android OAuth client
as the web audience or borrow an ID from the other environment.

Keep dev/staging downloads separate under `lele/config/native/`. Existing output
JSON files are protected from overwrite; review and deliberately replace public
metadata rather than fabricating missing OAuth values. See
[`lele/config/README.md`](../../lele/config/README.md) for active-file selection.

**Verified/imported 2026-10-17:** both files supplied at the repository root belong
to **dev**, not staging. Their public metadata was imported into the dev archive,
active Android/iOS native files and `firebase.dev.json`; the originals were left
untouched. The dev Google provider is enabled, and its configured client ID matches
the public web audience. The Android OAuth certificate matches the registered dev
debug SHA-1. Staging still has no Google provider, and its registration-only native
files were not replaced with dev's. Billing remains disabled in both projects.

Native Google now uses `google_sign_in` followed by Firebase's credential exchange;
the web path uses Firebase's popup. No contacts/Drive scopes or token persistence
are added. A missing OAuth config produces an explicit setup error, not fake login.

### iOS native gate

The supplied dev iOS client's **actual** reversed client ID is now registered in
Runner `Info.plist` under `CFBundleURLTypes/CFBundleURLSchemes`. The SDK gets client
IDs from Dart defines, but that does not install the URL scheme. When staging
Google is configured, switch its native files **and** Runner callback together;
never use dev's callback for staging Google. The Mac build validator now checks the
native OAuth IDs and Runner callback against the selected public config. Source
metadata checks and regression tests pass; Mac compilation and a physical iOS
sign-in remain unverified.

## 4. Apple — deferred

Membership, a Sign in with Apple-enabled App ID, native signing/capabilities and
Firebase provider settings must be completed before iOS launch. Do not ask for a
private key in chat. If a server/code-flow key is needed later, enter it only in
the intended server/provider secret configuration, never in public client files.
Do not claim that an existing entitlements file proves a provisioned capability.

The eventual linking path is authenticated and explicit; relay emails do not merge
families. See ADR 0005. Provider-ready and App Store-ready are separate gates.

## Acceptance still required

Check email verification/reset in a real inbox, native Google choose/cancel/new and
returning flows, logout/account switching, distinct dev/staging identities, iOS
callback behavior, and denied child writes before verification. App Check, backend
rules/functions/content, and physical devices must be ready for the complete flow.
Local tests and native debug compilation cannot substitute for those checks.

Local evidence on 2026-10-16: 365 Flutter tests passed, analysis had zero issues,
Android debug compiled/installed and Flutter MCP hot restart reported no Dart
runtime errors using the demo emulators. Neither real provider enablement nor a
Google consent/account-creation flow was verified at that point.

After the dev Google import on 2026-10-17, all **367 Flutter tests** passed and
whole-project analysis had zero issues. An Android debug build with the actual
dev config passed native/OAuth validation and compilation. A separate fresh launch
and MCP hot restart in demo-emulator mode reported no Dart runtime errors; known
demo FIS/App Check warnings remain. No real Google account selection, consent or
Firebase account creation was attempted. Apple remains deferred.
