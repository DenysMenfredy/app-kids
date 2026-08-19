# Lelê — Aprender a ler brincando

Flutter app (Android + iOS) implementing the Lelê literacy MVP for Brazilian
children ages 3–7, built from the Claude Design handoff
(`Mobile app design request-handoff.zip`) and the
`Literacy_App_MVP_Product_UX_Specification.pdf`.

## Product surface

**Parent flow:** Splash → Welcome carousel → Register/Login → Child profile →
Assessment (3 questions) → Parent dashboard → Paywall (founder pricing).

**Child flow:** Child home (journey map, streak/coins/XP) → Today's lesson →
4 activities (tap the letter, match upper/lowercase, trace with the finger,
listen and choose) → Reward (confetti, +XP/+coins/streak) → Book library.

All copy is pt-BR; child activities speak through the device TTS voice
(`pt-BR`).

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

- **State**: `flutter_riverpod` v3 Notifiers. `SessionController` owns
  parent/child profile + gamification (XP, coins, streak), persisted via
  `SharedPreferences` and mirrored to Firestore in Firebase mode.
- **Navigation**: `go_router` with named routes (`AppRoutes`).
- **Fonts**: Baloo 2 + Nunito bundled as assets (offline-first, no runtime
  fetch).
- **Accessibility**: looping decoration animations respect the platform
  reduce-motion setting; large touch targets throughout.

## Backend modes

The app runs against either an offline stub or the real Letrando backend
(`../backend`), selected at compile time by `AppConfig.useFirebase`:

| Concern | local (default) | firebase (`--dart-define=USE_FIREBASE=true`) |
| --- | --- | --- |
| Auth | `FakeAuthRepository` | Firebase Auth (email + Google) |
| Profile/child | SharedPreferences only | + Firestore `users/{uid}` mirror |
| Lesson progress | local only | + `updateProgress` / `completeLesson` callables |
| Premium | always false | streams `entitlements/premium` |
| Purchase | unavailable | `createCheckoutSession` → Stripe hosted page |

Local mode never touches a Firebase instance, so tests and pre-configuration
development work with no project set up. Firebase mode keeps the local store
as the immediate source of truth and treats sync as best-effort, so a flaky
network never blocks a child mid-lesson.

Backend authority is never second-guessed on the client: entitlement is read,
never written, and any read failure resolves to "not premium".

## Getting started

```bash
flutter pub get
flutter run            # local mode (no Firebase project needed)
flutter test           # 26 tests
flutter analyze        # zero issues
```

### Enabling the Firebase backend

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=letrando-dev   # overwrites lib/firebase_options.dart
flutter run --dart-define=USE_FIREBASE=true
```

`flutterfire configure` also writes the native config files
(`google-services.json`, `GoogleService-Info.plist`). Deploy the backend
first (see `../backend/README.md`) so the callables exist in
`southamerica-east1`.

## Known MVP simplifications

- The curriculum is still static in the app (`learningJourney`,
  `bookLibrary`, `todaysLessonId = 'lesson_008'`); the backend's content
  collections are not read yet.
- One child profile per account (`AppConfig.primaryChildId`), though the
  backend data model supports several.
- The assessment always places the child in module 3, mirroring the
  prototype, and its answers are not sent to the backend.
- XP/coins/streak are computed locally; the backend does not own them yet.
- FCM device registration (`registerDevice`) is not called from the app yet,
  so daily reminders won't reach a device.
