import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/child_profile.dart';
import '../domain/child_record.dart';
import 'session_controller.dart';

/// All children belonging to the currently authenticated parent.
///
/// The Firestore stream is keyed by UID so a new account never temporarily
/// inherits the previous account's last AsyncValue while its first snapshot
/// is loading.
final remoteChildrenProvider = Provider<AsyncValue<List<ChildRecord>>>((ref) {
  if (!AppConfig.useFirebase) return const AsyncData([]);

  final authState = ref.watch(firebaseAuthUserProvider);
  if (authState.isLoading) return const AsyncLoading();
  if (authState.hasError) {
    return AsyncError(authState.error!, authState.stackTrace!);
  }

  final user = authState.value;
  if (user == null) return const AsyncData([]);
  return ref.watch(_childrenForParentProvider(user.uid));
});

final _childrenForParentProvider = StreamProvider.autoDispose
    .family<List<ChildRecord>, String>((ref, uid) {
      final firestore = ref.watch(firestoreProvider);
      return firestore
          .collection('users/$uid/children')
          .snapshots()
          .map(
            (snapshot) => [
              for (final document in snapshot.docs)
                if (_profileFrom(document.data()) case final profile?)
                  ChildRecord(id: document.id, profile: profile),
            ],
          );
    });

/// The selected child ID, with a stable fallback after a reinstall or when
/// a previously selected profile has been removed from the parent's list.
final activeChildIdProvider = Provider<String>((ref) {
  final savedId = ref.watch(sessionProvider.select((state) => state.childId));
  if (!AppConfig.useFirebase) return savedId;
  final children = ref.watch(remoteChildrenProvider).value;
  if (children == null) return savedId;
  if (children.isEmpty) return AppConfig.primaryChildId;
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
