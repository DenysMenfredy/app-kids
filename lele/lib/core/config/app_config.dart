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
abstract final class AppConfig {
  static const bool useFirebase = bool.fromEnvironment('USE_FIREBASE');

  /// Region where all Letrando Cloud Functions are deployed.
  static const String functionsRegion = 'southamerica-east1';

  /// Single-child MVP: the one child profile lives under a fixed doc id.
  static const String primaryChildId = 'primary';

  /// Assessment document served during onboarding (backend `assessments/`).
  static const String defaultAssessmentId = 'assessment_pre_literacy_v1';
}
