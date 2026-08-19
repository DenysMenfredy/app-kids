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
│   ├── theme/                 # design tokens (colors, typography, ThemeData)
│   ├── services/tts_service.dart
│   ├── storage/local_storage.dart
│   └── widgets/               # LeleButton (3D press), LeleMascot, animations,
│                              # LeleTextField, ActivityScaffold
└── features/<feature>/
    ├── domain/                # entities (pure Dart, Equatable)
    ├── data/                  # repositories (auth is a swappable fake)
    ├── application/           # Riverpod Notifier controllers
    └── presentation/          # screens & widgets
```

- **State**: `flutter_riverpod` v3 Notifiers. `SessionController` owns
  parent/child profile + gamification (XP, coins, streak), persisted via
  `SharedPreferences` behind a provider override — swap in a backend sync
  later without touching UI.
- **Navigation**: `go_router` with named routes (`AppRoutes`).
- **Auth**: `AuthRepository` interface with a `FakeAuthRepository` so the
  full flow works offline; replace the provider with Firebase/your API.
- **Fonts**: Baloo 2 + Nunito bundled as assets (offline-first, no runtime
  fetch).
- **Accessibility**: looping decoration animations respect the platform
  reduce-motion setting; large touch targets throughout.

## Getting started

```bash
flutter pub get
flutter run            # pick an Android/iOS device
flutter test           # 9 tests: session persistence, lesson flow, onboarding E2E
flutter analyze        # zero issues
```

## Known MVP simplifications

- Auth, subscription purchase and the curriculum/progress data are local
  stubs (`FakeAuthRepository`, static `learningJourney`, `bookLibrary`).
- The assessment always places the child in module 3, mirroring the
  prototype.
- Payments need RevenueCat / native IAP wiring before store release.
