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

- **State**: `flutter_riverpod` v3 Notifiers. `SessionController` owns the
  parent/child profile, persisted via `SharedPreferences` and mirrored to
  Firestore. XP/coins/streak come from `progressProvider`, which reads the
  backend document in Firebase mode and the local session in demo mode.
- **Navigation**: `go_router` with named routes (`AppRoutes`).
- **Fonts**: Baloo 2 + Nunito bundled as assets (offline-first, no runtime
  fetch).
- **Illustrations**: the three onboarding images in
  `assets/images/onboarding/`. Source art arrives at ~1250px and ~1.2 MB
  each; it is resized to 750px on the long side (the slide renders at 260)
  and quantised to a 256-colour palette, which is visually lossless on flat
  illustration and takes the three from 3.6 MB to 172 KB. They are precached
  on the welcome screen so no slide opens with an empty gap.
- **Accessibility**: looping decoration animations respect the platform
  reduce-motion setting; large touch targets throughout.

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
| Purchase | unavailable | `createCheckoutSession` → Stripe hosted page |

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
flutter test           # 98 tests
flutter analyze        # zero issues
```

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
- One child profile per account (`AppConfig.primaryChildId`), though the
  backend data model supports several.
- FCM device registration (`registerDevice`) is not called from the app yet,
  so daily reminders won't reach a device.
