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
  return ref.watch(childrenForParentProvider(user.uid));
});

final childrenForParentProvider = StreamProvider.autoDispose
    .family<List<ChildRecord>, String>((ref, uid) {
      final firestore = ref.watch(firestoreProvider);
      return firestore
          .collection('users/$uid/children')
          .snapshots()
          .map(
            (snapshot) => [
              for (final document in snapshot.docs)
                ChildRecord(
                  id: document.id,
                  profile:
                      _profileFrom(document.data()) ??
                      (throw const FormatException('Invalid child profile')),
                ),
            ],
          );
    });

/// The actual selection, with absence distinct from loading or a failed read.
/// Firebase mode never substitutes a demo child or a cached profile here.
final selectedChildStateProvider = Provider<AsyncValue<ChildRecord?>>((ref) {
  final session = ref.watch(sessionProvider);
  if (!AppConfig.useFirebase) {
    return AsyncData(ChildRecord(id: session.childId, profile: session.child));
  }
  return resolveSelectedChild(
    ref.watch(remoteChildrenProvider),
    session.childId,
  );
});

AsyncValue<ChildRecord?> resolveSelectedChild(
  AsyncValue<List<ChildRecord>> state,
  String preferredId,
) {
  if (state.isLoading) return const AsyncLoading();
  if (state.hasError) return AsyncError(state.error!, state.stackTrace!);
  final children = state.requireValue;
  if (children.isEmpty) return const AsyncData(null);
  return AsyncData(
    children.firstWhere(
      (child) => child.id == preferredId,
      orElse: () => children.firstWhere(
        (child) => child.id == AppConfig.primaryChildId,
        orElse: () => children.first,
      ),
    ),
  );
}

/// The selected child ID, with a stable fallback after a reinstall or when
/// a previously selected profile has been removed from the parent's list.
final activeChildIdProvider = Provider<String>((ref) {
  return ref.watch(selectedChildStateProvider).value?.id ??
      AppConfig.primaryChildId;
});

/// The selected profile held by Firestore, if one has arrived.
final remoteChildProvider = Provider<ChildProfile?>((ref) {
  if (!AppConfig.useFirebase) return null;
  return ref.watch(selectedChildStateProvider).value?.profile;
});

/// The child the app should show — name, age and chosen avatar.
///
/// With the backend on this is the stored profile, so the choice survives a
/// reinstall and follows the family to another device. The on-device session
/// covers demo mode. Firebase views gate their content on the selected state.
final childProvider = Provider<ChildProfile>((ref) {
  if (!AppConfig.useFirebase) return ref.watch(sessionProvider).child;
  return ref.watch(selectedChildStateProvider).value?.profile ??
      ChildProfile.empty;
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
