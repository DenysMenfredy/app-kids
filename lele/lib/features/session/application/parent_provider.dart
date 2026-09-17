import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/parent_name.dart';
import 'session_controller.dart';

/// The parent's name as the backend knows it.
///
/// `users/{uid}.displayName` is the record of who registered; the Firebase
/// Auth profile is the fallback for the moment between sign-up and the
/// Firestore write landing. Empty when neither is known yet.
final remoteParentNameProvider = StreamProvider<String>((ref) {
  if (!AppConfig.useFirebase) return Stream.value('');
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);

  return auth.authStateChanges().asyncExpand((user) {
    if (user == null) return Stream.value('');
    return firestore.doc('users/${user.uid}').snapshots().map((snapshot) {
      final stored = (snapshot.data()?['displayName'] as String?)?.trim();
      if (stored != null && stored.isNotEmpty) return stored;
      return user.displayName?.trim() ?? '';
    });
  });
});

/// The name to greet the parent by.
///
/// With the backend on this is whoever actually registered — never the
/// prototype's stand-in. Demo mode keeps using the on-device session value.
final parentNameProvider = Provider<String>((ref) {
  if (!AppConfig.useFirebase) {
    return ref.watch(sessionProvider).parentName;
  }
  return ref.watch(remoteParentNameProvider).value ?? '';
});

/// Just the first name, for greeting the parent.
///
/// [parentNameProvider] stays the full name — this is only how the parent is
/// addressed on screen.
final parentFirstNameProvider = Provider<String>(
  (ref) => firstNameOf(ref.watch(parentNameProvider)),
);
