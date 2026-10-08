/// Backend mode selection.
///
/// The app runs in one of two modes:
///  - **local** (default): fake auth + on-device persistence. No Firebase
///    calls at all — the mode used by tests and by development before a
///    Firebase project is configured.
///  - **firebase**: real Firebase Auth / Firestore / Cloud Functions against
///    the Letrando backend (see `backend/`).
///
/// Enable Firebase mode after running `flutterfire configure`:
///   flutter run --dart-define=USE_FIREBASE=true
///
/// To run against the local emulators instead of a real project (see
/// `backend/dev.sh`), add USE_EMULATOR — no `flutterfire configure` needed:
///   flutter run --dart-define=USE_FIREBASE=true --dart-define=USE_EMULATOR=true
abstract final class AppConfig {
  static const bool useFirebase = bool.fromEnvironment('USE_FIREBASE');

  /// Point Firebase at the local emulator suite. Implies [useFirebase].
  static const bool useEmulator = bool.fromEnvironment('USE_EMULATOR');

  /// Host the emulators are reachable on. The Android emulator reaches the
  /// host machine at 10.0.2.2 rather than localhost; override for a physical
  /// device with `--dart-define=EMULATOR_HOST=<your LAN ip>`.
  static const String emulatorHostOverride = String.fromEnvironment(
    'EMULATOR_HOST',
  );

  /// Region where all Letrando Cloud Functions are deployed.
  static const String functionsRegion = 'southamerica-east1';

  /// Public reCAPTCHA site key for a real Firebase web build. A real web
  /// project must supply this before App Check is activated. Never use a
  /// debug provider or a Firebase emulator in a release build.
  static const String appCheckWebSiteKey = String.fromEnvironment(
    'APP_CHECK_RECAPTCHA_SITE_KEY',
  );

  /// Stripe Checkout is a web-only channel. Keep it disabled until the
  /// seven-day trial and the web App Check registration are verified.
  static const bool enableWebCheckout = bool.fromEnvironment(
    'ENABLE_WEB_CHECKOUT',
  );

  /// Legacy profile ID used only to find accounts created before server-issued
  /// child IDs were introduced.
  static const String primaryChildId = 'primary';

  /// Assessment document served during onboarding (backend `assessments/`).
  static const String defaultAssessmentId = 'assessment_pre_literacy_v1';

  /// Lesson the journey opens on in demo mode: partway through module 3,
  /// like the design prototype's child. The mockup's "Lição 8" and "42%"
  /// were independent placeholders; both are derived from this id now, so
  /// the demo picks the mid-module position the screens were drawn around.
  static const String demoLessonId = 'lesson_010';
}
