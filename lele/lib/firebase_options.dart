// PLACEHOLDER — replace by running the FlutterFire CLI:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=letrando-dev
//
// The CLI overwrites this file with real per-platform options and adds the
// native config files (google-services.json / GoogleService-Info.plist).
// Until then the app must run in local mode (USE_FIREBASE unset/false).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'firebase_options.dart is a placeholder. Run '
      '`flutterfire configure --project=letrando-dev` before enabling '
      'USE_FIREBASE.',
    );
  }
}
