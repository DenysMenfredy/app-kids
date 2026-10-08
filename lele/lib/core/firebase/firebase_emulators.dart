import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// Ports from `backend/firebase.json`.
const _authPort = 9099;
const _firestorePort = 8080;
const _functionsPort = 5001;

/// Credentials for a `demo-` project. Firebase tooling treats that prefix as
/// emulator-only and never reaches production with it, so these values are
/// safe to commit and work without running `flutterfire configure`.
///
/// The emulators must run under the same project id — `backend/dev.sh` passes
/// `--project demo-letrando`.
const demoFirebaseOptions = FirebaseOptions(
  // Firebase Installations validates API-key syntax even when Functions
  // calls target an emulator. This deliberately fake, 39-character key
  // passes that local check without identifying a real Firebase project.
  apiKey: 'AIzaSy000000000000000000000000000000000',
  appId: '1:000000000000:web:0000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'demo-letrando',
);

/// Where the emulators are reachable from the running app.
String get emulatorHost {
  if (AppConfig.emulatorHostOverride.isNotEmpty) {
    return AppConfig.emulatorHostOverride;
  }
  // An Android emulator reaches its host machine through this alias; every
  // other target (web, desktop, iOS simulator) shares the host's loopback.
  // `defaultTargetPlatform` is used rather than dart:io, which web can't
  // import at all.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return '10.0.2.2';
  }
  return 'localhost';
}

/// Points the Firebase SDKs at the local emulator suite. Call once, right
/// after `Firebase.initializeApp`.
Future<void> connectToEmulators() async {
  final host = emulatorHost;
  FirebaseFirestore.instance.useFirestoreEmulator(host, _firestorePort);
  FirebaseFunctions.instanceFor(
    region: AppConfig.functionsRegion,
  ).useFunctionsEmulator(host, _functionsPort);
  await FirebaseAuth.instance.useAuthEmulator(host, _authPort);
  debugPrint('Firebase: using emulators on $host');
}
