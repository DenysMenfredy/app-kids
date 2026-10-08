import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// Firebase service instances. Only read these when [AppConfig.useFirebase]
/// is true — in local mode they would throw because Firebase.initializeApp
/// never ran.

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

/// The signed-in Firebase user, exposed as a reactive dependency for local
/// state that must be isolated between parent accounts.
final firebaseAuthUserProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

/// Functions client pinned to the backend's region — calling the default
/// us-central1 would fail against the Letrando deployment.
final functionsProvider = Provider<FirebaseFunctions>(
  (ref) => FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion),
);
