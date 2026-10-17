import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart';

import 'core/config/firebase_build_config.dart';

/// Options selected explicitly by --dart-define-from-file, never a default project.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    const config = FirebaseBuildConfig.compiled;
    final platform = kIsWeb
        ? 'web'
        : defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    config.validate(platform: platform, release: kReleaseMode);
    final prefix = 'FIREBASE_${platform.toUpperCase()}';
    return FirebaseOptions(
      apiKey: config.value('${prefix}_API_KEY'),
      appId: config.value('${prefix}_APP_ID'),
      messagingSenderId: config.value('FIREBASE_MESSAGING_SENDER_ID'),
      projectId: config.projectId,
      storageBucket: config.value('FIREBASE_STORAGE_BUCKET'),
      iosBundleId: platform == 'ios'
          ? config.value('FIREBASE_IOS_BUNDLE_ID')
          : null,
      authDomain: platform == 'web'
          ? config.value('FIREBASE_AUTH_DOMAIN')
          : null,
    );
  }
}
