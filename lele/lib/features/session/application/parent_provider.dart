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
final remoteParentNameProvider = Provider<AsyncValue<String>>((ref) {
  if (!AppConfig.useFirebase) return const AsyncData('');

  final authState = ref.watch(firebaseAuthUserProvider);
  if (authState.isLoading) return const AsyncLoading();
  if (authState.hasError) {
    return AsyncError(authState.error!, authState.stackTrace!);
  }
  final user = authState.value;
  if (user == null) return const AsyncData('');

  return ref.watch(
    _parentNameForUidProvider((uid: user.uid, fallback: user.displayName)),
  );
});

final _parentNameForUidProvider = StreamProvider.autoDispose
    .family<String, ({String uid, String? fallback})>((ref, scope) {
      final firestore = ref.watch(firestoreProvider);
      return firestore.doc('users/${scope.uid}').snapshots().map((snapshot) {
        final stored = (snapshot.data()?['displayName'] as String?)?.trim();
        if (stored != null && stored.isNotEmpty) return stored;
        return scope.fallback?.trim() ?? '';
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
