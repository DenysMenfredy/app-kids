import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/child_profile.dart';
import '../domain/child_record.dart';
import 'session_controller.dart';

/// All children belonging to the currently authenticated parent.
final remoteChildrenProvider = StreamProvider<List<ChildRecord>>((ref) {
  if (!AppConfig.useFirebase) return Stream.value(const []);
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);

  return auth.authStateChanges().asyncExpand((user) {
    if (user == null) return Stream<List<ChildRecord>>.value(const []);
    return firestore
        .collection('users/${user.uid}/children')
        .snapshots()
        .map(
          (snapshot) => [
            for (final document in snapshot.docs)
              if (_profileFrom(document.data()) case final profile?)
                ChildRecord(id: document.id, profile: profile),
          ],
        );
  });
});

/// The selected child ID, with a stable fallback after a reinstall or when
/// a previously selected profile has been removed from the parent's list.
final activeChildIdProvider = Provider<String>((ref) {
  final savedId = ref.watch(sessionProvider.select((state) => state.childId));
  if (!AppConfig.useFirebase) return savedId;
  final children = ref.watch(remoteChildrenProvider).value;
  if (children == null || children.isEmpty) return savedId;
  for (final child in children) {
    if (child.id == savedId) return savedId;
  }
  for (final child in children) {
    if (child.id == AppConfig.primaryChildId) return child.id;
  }
  return children.first.id;
});

/// The selected profile held by Firestore, if one has arrived.
final remoteChildProvider = Provider<ChildProfile?>((ref) {
  final childId = ref.watch(activeChildIdProvider);
  final children = ref.watch(remoteChildrenProvider).value;
  if (children == null) return null;
  for (final child in children) {
    if (child.id == childId) return child.profile;
  }
  return null;
});

/// The child the app should show — name, age and chosen avatar.
///
/// With the backend on this is the stored profile, so the choice survives a
/// reinstall and follows the family to another device. The on-device session
/// covers demo mode and the moment between saving and the write landing.
final childProvider = Provider<ChildProfile>((ref) {
  if (!AppConfig.useFirebase) return ref.watch(sessionProvider).child;
  final children = ref.watch(remoteChildrenProvider);
  if (children.isLoading) return ref.watch(sessionProvider).child;
  if (children.hasError) return ChildProfile.defaultProfile;
  final activeId = ref.watch(activeChildIdProvider);
  for (final record in children.requireValue) {
    if (record.id == activeId) return record.profile;
  }
  // Don't keep showing a deleted profile from local cache after Firestore
  // confirms that it is no longer available to this parent.
  return ChildProfile.defaultProfile;
});

ChildProfile? _profileFrom(Map<String, dynamic> data) {
  final name = data['name'];
  final age = data['age'];
  if (name is! String ||
      name.trim().isEmpty ||
      age is! int ||
      age < 3 ||
      age > 7) {
    return null;
  }
  final avatarId = data['avatarId'];
  return ChildProfile(
    name: name.trim(),
    age: age,
    avatar: childAvatarFromId(avatarId is String ? avatarId : null),
  );
}
