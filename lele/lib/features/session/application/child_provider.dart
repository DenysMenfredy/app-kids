import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/child_profile.dart';
import 'session_controller.dart';

/// The child profile as the backend holds it.
///
/// Null until a profile exists, so the caller can fall back to what the
/// parent typed during onboarding rather than flashing a default.
final remoteChildProvider = StreamProvider<ChildProfile?>((ref) {
  if (!AppConfig.useFirebase) return Stream.value(null);
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);

  return auth.authStateChanges().asyncExpand((user) {
    if (user == null) return Stream<ChildProfile?>.value(null);
    return firestore
        .doc('users/${user.uid}/children/${AppConfig.primaryChildId}')
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      const fallback = ChildProfile.defaultProfile;
      return ChildProfile(
        name: (data['name'] as String?)?.trim().isNotEmpty == true
            ? (data['name'] as String).trim()
            : fallback.name,
        age: (data['age'] as num?)?.toInt() ?? fallback.age,
        avatar: childAvatarFromId(data['avatarId'] as String?),
      );
    });
  });
});

/// The child the app should show — name, age and chosen avatar.
///
/// With the backend on this is the stored profile, so the choice survives a
/// reinstall and follows the family to another device. The on-device session
/// covers demo mode and the moment between saving and the write landing.
final childProvider = Provider<ChildProfile>((ref) {
  if (!AppConfig.useFirebase) return ref.watch(sessionProvider).child;
  return ref.watch(remoteChildProvider).value ??
      ref.watch(sessionProvider).child;
});
