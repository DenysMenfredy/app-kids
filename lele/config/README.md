# Explicit Firebase environments

Debug demo remains `flutter run`. For the local Firebase suite:

```sh
flutter run --dart-define=USE_FIREBASE=true --dart-define=USE_EMULATOR=true
```

Real builds require an explicit `APP_ENV` (`dev`, `staging`, `production`) and
public Firebase metadata from the corresponding console/FlutterFire output.
There is no implicit default project. Release builds reject demo, emulators,
dev projects, mismatched project/app/package IDs and missing native files.
Current Android package and iOS bundle are both `br.com.lele.lele`; this change
does not invent or register flavor-specific IDs. Each project must have its
own registration for the selected native ID. Flavor/ID separation remains a
console/signing task; do not reuse a registration from another project.

1. Have the project owner register/confirm the apps, OAuth providers and signing
   fingerprints in the intended Firebase project. Use FlutterFire CLI to obtain
   the generated public options for that project; do not manufacture app IDs.
2. Create `firebase.dev.json`, `firebase.staging.json` or
   `firebase.production.json` here using `firebase.example.json` as the key
   schema. Copy the generated per-platform options, project number and bucket.
   Replace every `REPLACE_...`; the example deliberately cannot pass a build.
   These files contain public client configuration only. Never include service
   account JSON, private Apple keys, purchase tokens, passwords or server secrets.
3. Select that environment's `google-services.json` at
   `android/app/google-services.json` and `GoogleService-Info.plist` at
   `ios/Runner/GoogleService-Info.plist`. Complete FlutterFire/native resource,
   OAuth URL-scheme and capability setup on the owning Android/Mac environment.
   The validators compare the native options to the selected public JSON.
4. Check/build explicitly:

```sh
dart tool/verify_firebase_config.dart --config=config/firebase.staging.json --platform=android --environment=staging --release
flutter run --dart-define-from-file=config/firebase.dev.json
flutter build apk --release --dart-define-from-file=config/firebase.staging.json
```

The active native files must first match the requested environment; see the
selection commands below. Android release CI selects the matching native file
before validation and derives the distribution project/app from the validated
public config, not from the working directory's Firebase alias.

On Mac, validate `--platform=ios` before the corresponding `flutter build ios`.
The Xcode build phase invokes the same validator using `DART_DEFINES` and reads
native plist values via PlistBuddy. Android pre-build tasks also validate direct
Gradle invocations, so bypassing the workflow does not create a demo release.
No actual iOS build has been validated on this Linux host.

App Check activates before protected requests. Debug builds use debug providers;
register their tokens only in dev/staging, outside source/config files. Release
uses Play Integrity or App Attest with DeviceCheck fallback. Web auth builds
add generated `FIREBASE_WEB_APP_ID`, `FIREBASE_WEB_API_KEY`,
`FIREBASE_AUTH_DOMAIN` and a public `APP_CHECK_RECAPTCHA_SITE_KEY`; web billing is
not supported. The default Firebase auth domain is currently required; a custom
domain needs a separately reviewed allowlist, not weakening validation.

The release workflow can select staging or production; tags select production.
Use the corresponding GitHub Environment's signing and distribution settings.
The configured release must never be uploaded to another Environment's project.
The public config/native files must be supplied before the workflow can succeed.
Existing native IDs are shared across projects, so use distinct test devices or
uninstall consciously when switching signed environments; automatic flavor
isolation is not claimed here.

This validation proves local configuration coherence, not console existence,
OAuth correctness, App Check registration, Firebase IAM or store billing.

## Registered environments — 2026-10-16

The owner signed in and accepted Firebase's terms. The following projects and
registrations were then created and verified active through the Management API:

| Environment | Project number | Android app ID | iOS app ID |
| --- | --- | --- | --- |
| `letrando-dev` | `293659867381` | `1:293659867381:android:45886330baeba918606dbc` | `1:293659867381:ios:870c4e97cd731aa9606dbc` |
| `letrando-staging` | `293526780029` | `1:293526780029:android:f65e89498bbfe07903d914` | `1:293526780029:ios:a5741edd689a05f203d914` |

Both native IDs are `br.com.lele.lele`. Billing was verified disabled before
registration; no billing account was linked, production project created, backend
deployed, or database/content provisioned during this setup. The generated
Storage bucket field is public SDK metadata, not proof that a bucket exists.

Public files downloaded directly from Firebase are kept separately:

- `native/dev/google-services.json` and `native/dev/GoogleService-Info.plist`;
- `native/staging/google-services.json` and `native/staging/GoogleService-Info.plist`.

The offline generator produced `firebase.dev.json` and `firebase.staging.json`
from these files, including both platforms. The active Android/iOS native files
are currently **dev**. Public Firebase API keys in these files identify the app;
they are not administrative credentials or a substitute for Rules/App Check.
Never put debug App Check tokens, signing keys or service credentials here.

Staging Google/signing/callback setup, Apple capabilities/APNs, App Check
registration, Firestore/rules/functions/content and physical-device acceptance
remain open. Registration alone does not make
the full sign-in/child/lesson flow operational. iOS compilation still requires
a Mac; no iOS build is claimed from this Linux host.

Auth follow-up — 2026-10-17: ordinary Auth and email/password are enabled in both
projects. Dev's existing Android debug SHA-1/SHA-256 are registered. Both refreshed
files supplied at the repository root are **dev**; their originals remain intact.
The dev archive and active native files now include the actual Google OAuth IDs,
copied into `firebase.dev.json`; Runner's URL scheme matches the dev iOS client.
Readback confirms the enabled dev Google provider uses that same web audience.
The Android dev-config debug build passed. Staging Google remains absent, staging
signing is open, and its registration-only files have no Google OAuth fields.
See [Auth provider setup](../../backend/docs/auth-providers.md). The owner has no
Apple Developer membership yet, so Apple setup remains a release gate. No real
Google account creation, consent flow or iOS device acceptance is claimed.

## Select a local environment

From `lele/`, dev is already selected. Its explicit run configuration is:

```sh
dart tool/verify_firebase_config.dart --config=config/firebase.dev.json --platform=android --environment=dev
flutter run --dart-define-from-file=config/firebase.dev.json
```

To select staging, intentionally replace **both** active native files together:

```sh
cp config/native/staging/google-services.json android/app/google-services.json
cp config/native/staging/GoogleService-Info.plist ios/Runner/GoogleService-Info.plist
dart tool/verify_firebase_config.dart --config=config/firebase.staging.json --platform=android --environment=staging --release
flutter run --dart-define-from-file=config/firebase.staging.json
```

To return to dev:

```sh
cp config/native/dev/google-services.json android/app/google-services.json
cp config/native/dev/GoogleService-Info.plist ios/Runner/GoogleService-Info.plist
```

Google-enabled iOS environments also require their actual
`GOOGLE_IOS_REVERSED_CLIENT_ID` in Runner `Info.plist`'s `CFBundleURLSchemes`.
The current scheme is dev's; copying a native plist alone does not switch it.
Once staging Google is configured, update the callback with its own downloaded
value and run the Mac validator before building. It rejects a configured Google
client whose native IDs or callback do not match; `--ios-info` can select an
environment-specific Runner plist. The current staging config does not enable
Google, and a leftover dev scheme does not make staging Google functional.

Stop and relaunch when switching; hot reload/restart cannot switch native Firebase
identity or compile-time defines. The package/bundle ID is shared, so installing
another environment replaces the existing app, not a side-by-side flavor.
No Firebase user or child data is copied between projects.

Validation can inspect staging without changing the active dev files:

```sh
dart tool/verify_firebase_config.dart --config=config/firebase.staging.json --platform=android --environment=staging --release --native=config/native/staging/google-services.json
```

On a Mac, use `--platform=ios` with the matching native plist path. Local Android
checks passed for dev and staging; staging validation against the active dev file
was also confirmed to fail. Generator validation checked the iOS metadata, but is
not a substitute for the Mac-native validator or a physical iOS run.

## Refresh registrations/configuration

Use the same project-owner account. Review consent prompts yourself; never
commit the CLI credential store. From the repository root:

```sh
cd /home/denys7/projects/app-kids/backend
nvm use
node test/rules/node_modules/firebase-tools/lib/bin/firebase.js login
node test/rules/node_modules/firebase-tools/lib/bin/firebase.js projects:list
node test/rules/node_modules/firebase-tools/lib/bin/firebase.js apps:list --project letrando-dev
node test/rules/node_modules/firebase-tools/lib/bin/firebase.js apps:list --project letrando-staging
```

These commands only list existing resources. If a project/app is absent, stop and
confirm its owner/registration before creating anything; the offline generator
does not create remote resources. Production remains intentionally unconfigured.
Download each project's Android `google-services.json` and iOS
`GoogleService-Info.plist` from Project settings → Your apps. Keep dev and
staging downloads in separate directories. They must use `br.com.lele.lele`.
Only these public client files are needed, never a service-account/private key.

An offline generator converts the downloaded public files to build defines,
checks project/platform identity, prints no key values, and refuses overwrites:

```sh
cd /home/denys7/projects/app-kids/lele
dart tool/generate_firebase_config.dart --environment=dev --android=/path/to/dev/google-services.json --ios=/path/to/dev/GoogleService-Info.plist
dart tool/generate_firebase_config.dart --environment=staging --android=/path/to/staging/google-services.json --ios=/path/to/staging/GoogleService-Info.plist
```

The generated dev/staging JSON files now exist, so these commands intentionally
refuse to overwrite them. Review refreshed files and their environment identity
before replacing an existing public config.

If only Android is available, omit `--ios`; no iOS options will be invented.
Select the corresponding native files in the active build locations from step
3 before validation. Auth, App Check, OAuth/native resources, APNs and actual
device testing still need configuration; successful generation is not a deploy.
