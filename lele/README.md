# Lelê — Aprender a ler brincando

Flutter app (Android + iOS) implementing the Lelê literacy MVP for Brazilian
children ages 3–7, built from the Claude Design handoff
(`Mobile app design request-handoff.zip`) and the
`Literacy_App_MVP_Product_UX_Specification.pdf`.

## Product surface

**Parent flow:** Splash → Welcome carousel → Register/Login → Child profile →
Assessment (3 questions) → Parent dashboard → Paywall (founder pricing).

**Child flow:** Child home (journey map anchored on the child's current
lesson, streak/coins/XP) → Today's lesson → its 4 activities, with the
letters and words served by the backend (tap the letter, match
upper/lowercase, trace with the finger, listen and choose) → Reward
(confetti, +XP/+coins/streak) → Book library.

All copy is pt-BR; child activities speak through the device TTS voice.

### Speech (pt-BR)

`TtsService` names the voice rather than only setting the language. Setting
the language alone leaves the engine free to keep its default voice — on a
machine whose default is German, that reads Portuguese with German
phonetics, which is exactly what it sounds like.

It picks an exact pt-BR voice, falls back to European Portuguese (wrong
accent, right language), and logs loudly when the device has no Portuguese
at all rather than mispronouncing everything in silence.

Naming the voice is not sufficient on the web, because of *when* it is
named. flutter_tts resolves both the language and the voice against
`speechSynthesis.getVoices()` **synchronously**, but Chrome returns an empty
list on the first call and populates it asynchronously. Configuring on page
load therefore matched nothing and left the utterance on the browser
default — German, on a machine set up in German, which is what the bug
looked like. `TtsService` now waits for a non-empty voice list (bounded,
~3s) before configuring, doesn't mark itself configured if the list never
arrived, and warms up in the background so the child's first instruction
isn't delayed.

The speech rate is per-platform on purpose: flutter_tts doubles the value on
Android and passes it straight through on iOS, where 0.5 is normal, but on
web it becomes `SpeechSynthesisUtterance.rate`, where **1.0** is normal. One
shared value ran browser speech at 0.45x — slurred, and half the reason it
sounded wrong.

On Android 11+ the app also has to declare the `TTS_SERVICE` intent in the
manifest's `queries` block. Without it, package-visibility rules hide the
speech engine entirely, the voice list comes back empty and every
instruction is read by the system default voice — the same failure as the
web race, from a different cause.

**If speech still sounds off**, the device is probably missing the voice:

- Android: Settings › Language & input › Text-to-speech → install the
  Português (Brasil) voice data for the Google engine.
- Chrome on Linux: voices come from speech-dispatcher; install a pt-BR one
  (`espeak-ng` ships one) or test in Chrome with Google's cloud voices.
- iOS: Settings › Accessibility › Spoken Content › Voices → Português
  (Brasil).

## Architecture

Feature-first clean architecture:

```
lib/
├── main.dart                  # bootstrap: orientation, SharedPreferences, ProviderScope
├── app/
│   ├── app.dart               # MaterialApp.router
│   └── router/app_router.dart # go_router: all 18 routes, named navigation
├── core/
│   ├── config/app_config.dart # backend mode flag (USE_FIREBASE)
│   ├── firebase/              # FirebaseAuth/Firestore/Functions providers
│   ├── theme/                 # design tokens (colors, typography, ThemeData)
│   ├── services/tts_service.dart
│   ├── storage/local_storage.dart
│   └── widgets/               # LeleButton (3D press), LeleMascot, animations,
│                              # LeleTextField, ActivityScaffold
└── features/<feature>/
    ├── domain/                # entities (pure Dart, Equatable)
    ├── data/                  # repositories/services: one local impl +
    │                          # one Firebase impl behind each interface
    ├── application/           # Riverpod Notifier controllers
    └── presentation/          # screens & widgets
```

- **State**: `flutter_riverpod` v3 Notifiers. `SessionController` owns the
  parent/child profile, persisted via `SharedPreferences` and mirrored to
  Firestore. XP/coins/streak come from `progressProvider`, which reads the
  backend document in Firebase mode and the local session in demo mode.
- **Navigation**: `go_router` with named routes (`AppRoutes`).
- **Fonts**: Baloo 2 + Nunito bundled as assets (offline-first, no runtime
  fetch).
- **App icon**: `store/app-icon-master.png` is the source of truth;
  `tool/generate_icons.py` regenerates every launcher and store asset from
  it. The master is a pre-rounded squircle on black, which neither store
  wants — iOS masks the icon itself and rejects an alpha channel, Android
  masks adaptive icons to the OEM's shape — so the artwork is lifted off its
  background and each platform gets the shape it expects. The Android
  adaptive foreground sits inside the 66dp safe circle so the "Lelê"
  wordmark survives a circular mask; run the script again after replacing
  the master.
- **Illustrations**: the three onboarding images in
  `assets/images/onboarding/`. Source art arrives at ~1250px and ~1.2 MB
  each; it is resized to 750px on the long side (the slide renders at 260)
  and quantised to a 256-colour palette, which is visually lossless on flat
  illustration and takes the three from 3.6 MB to 172 KB. They are precached
  on the welcome screen so no slide opens with an empty gap.
- **Accessibility**: looping decoration animations respect the platform
  reduce-motion setting; large touch targets throughout.
- **Responsive**: `core/layout/adaptive_page.dart`. `AdaptivePage` fills the
  screen when the content fits and scrolls when it does not, so a layout
  designed for a tall phone degrades instead of stranding its button off the
  bottom; `AdaptiveWidth` caps the column so a tablet or unfolded foldable
  shows a readable measure rather than one stretched line. `test/responsive_test.dart`
  mounts all 18 screens at 12 real device sizes — 320x568 up to iPad Pro,
  both folds, and landscape — and fails on any overflow or on a primary
  button that lands off-screen with nothing to scroll.

## Backend modes

The app runs against either an offline stub or the real Letrando backend
(`../backend`), selected at compile time by `AppConfig.useFirebase`:

| Concern | local (default) | firebase (`--dart-define=USE_FIREBASE=true`) |
| --- | --- | --- |
| Auth | `FakeAuthRepository` | Firebase Auth (email + Google), with password reset and sign-out |
| Parent's name | on-device session | `users/{uid}.displayName` from the backend |
| Route access | ungated | signed-out visitors are sent to sign-in |
| Profile/child | SharedPreferences only | + Firestore `users/{uid}` mirror |
| Assessment | bundled copy of the questions | `assessments/{id}` from Firestore |
| Placement | fixed fallback (module 3) | scored server-side by `submitAssessment` |
| Journey position | advances on device, persisted | `currentLessonId`, advanced by `completeLesson` |
| Child name/age/avatar | on-device session | `children/{id}` from Firestore |
| Lesson content | one bundled sample lesson | `lessons/{id}` + `activities` from Firestore |
| Lesson progress | local only | + `updateProgress` / `completeLesson` callables |
| XP / coins / streak | computed on device | streamed from `gamification/{childId}` |
| Premium | always false | streams `entitlements/premium` |
| Purchase | unavailable | mobile beta disabled; web checkout opt-in after the real trial is ready |

Local mode never touches a Firebase instance, so tests and pre-configuration
development work with no project set up. Firebase mode keeps the local store
as the immediate source of truth and treats sync as best-effort, so a flaky
network never blocks a child mid-lesson.

Backend authority is never second-guessed on the client: entitlement, XP,
coins, streak and the assessment placement are read, never written. Any
entitlement read failure resolves to "not premium"; a failed assessment
submission falls back to a default placement so onboarding can't dead-end,
and the real placement is written on the next successful submission
(`backend/docs/adr/0003-server-owned-progress-and-assessment.md`).

## Getting started

```bash
flutter pub get
flutter run            # local mode (no Firebase project needed)
flutter test           # 129 tests
flutter analyze        # zero issues
```

### Firebase emulators on Android

From the repository root, start the backend in one terminal:

```bash
cd backend
nvm use
./dev.sh
```

Start an Android virtual device, then run the app in a second terminal:

```bash
cd lele
flutter run --dart-define=USE_FIREBASE=true --dart-define=USE_EMULATOR=true
```

Android virtual devices reach the host at `10.0.2.2`. Firebase Auth uses
HTTP on port 9099, so the debug and profile source sets allow cleartext
traffic only to `10.0.2.2`, `localhost` and `127.0.0.1`. Release builds do
not include this exception and reject `USE_EMULATOR=true` (ADR 0009).
After changing an Android manifest or network policy, stop the running app
and run the command again to rebuild and reinstall it; hot reload and hot
restart cannot apply native configuration changes.

Demo Firebase options also need to satisfy native SDK format checks: the
emulator API key is deliberately fake but has the 39-character format
required by Firebase Installations. A short key such as `demo-api-key`
allows Auth REST signup but can fail native Functions calls before they
reach the emulator (ADR 0010). After changing Firebase initialization
options, stop the app and start a fresh `flutter run` to reset the native
SDK instance.

For a physical Android device connected over USB, forward the emulator
ports and use the permitted loopback host:

```bash
adb reverse tcp:9099 tcp:9099
adb reverse tcp:8080 tcp:8080
adb reverse tcp:5001 tcp:5001
flutter run --dart-define=USE_FIREBASE=true --dart-define=USE_EMULATOR=true \
  --dart-define=EMULATOR_HOST=127.0.0.1
```

A custom LAN address supplied through `EMULATOR_HOST` also needs an
explicit entry in the debug/profile network policies. Emulator mode skips
App Check activation (ADR 0004), so Firebase Auth may log
`No AppCheckProvider installed`; that warning does not block local signup.

### Book library

The library loads published `books` metadata and reads authorized pages from
`bookContents`. The initial catalog contains six original short pt-BR stories:
`O Sapo e a Lua` and `A Festa das Vogais` are free; the other four require the
server-owned `premium_books` entitlement. Reader controls include page turns,
pt-BR read-aloud, replay and return to the shelf. A bookmark resumes the selected
child's last page without granting XP or coins.

`backend/dev.sh` seeds books automatically, including into existing emulator
exports. To refresh only books while the demo backend is already running:

```bash
cd backend
nvm use
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npm --prefix functions run seed -- \
  --project demo-letrando --only books,bookContents
```

The integration check requires those same running emulators:

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
npm --prefix functions run test:books:smoke
```

Real projects require the new Rules and `saveBookBookmark` callable deployed,
plus catalog/page publication. An editor first upserts `books` metadata and
matching `bookContents`, then publishes the `books` document through
`manageContent`; publication validates every page and publishes both documents
atomically. See ADR 0012. Demo mode bundles only the two free sample texts.

### Releasing on Android

Release builds are signed from `android/key.properties`, which is gitignored
and never generated by the build:

```properties
storeFile=upload-keystore.jks   # relative to android/app/
storePassword=...
keyAlias=upload
keyPassword=...
```

Without that file the release build still works but signs with the **debug**
key and says so loudly — it is fine for sideloading and rejected by Play. An
incomplete file fails the build naming the missing property rather than
falling back, so a misconfigured CI run cannot quietly ship a debug-signed
artifact.

Create the upload keystore once and keep it somewhere you cannot lose it:

```bash
keytool -genkeypair -v -keystore upload-keystore.jks \
  -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Losing it means never updating the app again, so enrol in **Play App
Signing**: Google then holds the app signing key and the upload key stays
replaceable. CI keeps the keystore base64-encoded in the `production`
GitHub Environment (`.github/workflows/release-android.yml`).

### Enabling the Firebase backend

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=letrando-dev   # overwrites lib/firebase_options.dart
flutter run --dart-define=USE_FIREBASE=true
```

`flutterfire configure` also writes the native config files
(`google-services.json`, `GoogleService-Info.plist`). Deploy the backend and
seed its content first (see `../backend/README.md`): the callables must exist
in `southamerica-east1`, and the onboarding assessment is read from
Firestore.

## Known MVP simplifications

- The curriculum *shape* is still duplicated in the app (`curriculum` in
  `features/learning/domain`, `bookLibrary`) even though the backend seeds
  the same 7 modules. Exercises are not duplicated — the lesson the child
  plays is fetched from `lessons/{id}` + `activities`. A test compares the
  app's module list against `backend/seed/modules/`, and another checks the
  offline sample lesson against the seed, so neither copy can drift.
- Demo mode ships a single sample lesson. The journey position still
  advances as lessons are finished — the map and dashboard move — but the
  exercises themselves repeat, because there is only one lesson bundled.
- Sign-in validates and reports errors per field, but there is no e-mail
  verification step and no account deletion yet (the latter is an LGPD
  requirement tracked in the backend README).
- Firebase mode supports multiple server-issued child profiles per parent;
  demo mode keeps one local profile. Legacy `primary` records remain readable
  until the staging migration is counted and rehearsed.
- The static book shelf is demo-only. Firebase mode shows an empty-library
  state until a published backend book catalog and real pages are available.
- FCM device registration (`registerDevice`) is not called from the app yet,
  so daily reminders won't reach a device.
