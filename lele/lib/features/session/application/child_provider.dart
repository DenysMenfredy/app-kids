import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/child_profile.dart';
import '../domain/child_record.dart';
import '../domain/primary_child_migration.dart';
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
  final children = ref.watch(childrenForParentProvider(user.uid));
  final migration = ref.watch(primaryChildMigrationProvider(user.uid));
  if (children.isLoading || migration.isLoading) return const AsyncLoading();
  if (children.hasError) {
    return AsyncError(children.error!, children.stackTrace!);
  }
  // A failed migration read is not evidence of a missing mapping; keep the
  // legacy list rather than hiding a child from the parent.
  return AsyncData(
    applyPrimaryChildMigration(children.requireValue, migration.asData?.value),
  );
});

/// The server-owned `primary` → server-child mapping for the signed-in parent.
/// Missing/denied/unavailable reads resolve to null, which keeps old clients
/// on `children/primary`.
final primaryChildMigrationProvider = StreamProvider.autoDispose
    .family<PrimaryChildMigration?, String>((ref, uid) {
      final firestore = ref.watch(firestoreProvider);
      Stream<PrimaryChildMigration?> watch() async* {
        try {
          await for (final snapshot
              in firestore
                  .doc('users/$uid/migrations/primaryChild')
                  .snapshots()) {
            yield PrimaryChildMigration.fromMap(snapshot.data());
          }
        } on FirebaseException catch (error) {
          if (error.code == 'permission-denied' ||
              error.code == 'unavailable' ||
              error.code == 'not-found') {
            yield null;
            return;
          }
          debugPrint('primary child migration read failed: $error');
          yield null;
        }
      }

      return watch();
    });

/// The child ID that replaces `primary` after a completed migration, or null.
final migratedPrimaryChildIdProvider = Provider<String?>((ref) {
  if (!AppConfig.useFirebase) return null;
  final uid = ref.watch(firebaseAuthUserProvider).value?.uid;
  if (uid == null) return null;
  return ref
      .watch(primaryChildMigrationProvider(uid))
      .asData
      ?.value
      ?.newChildId;
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
    migratedNewChildId: ref.watch(migratedPrimaryChildIdProvider),
  );
});

AsyncValue<ChildRecord?> resolveSelectedChild(
  AsyncValue<List<ChildRecord>> state,
  String preferredId, {
  String? migratedNewChildId,
}) {
  if (state.isLoading) return const AsyncLoading();
  if (state.hasError) return AsyncError(state.error!, state.stackTrace!);
  final children = state.requireValue;
  if (children.isEmpty) return const AsyncData(null);

  // A parent whose cached selection is the legacy ID must land on the
  // server-issued child, not on whichever non-primary document sorts first.
  if (preferredId == AppConfig.primaryChildId && migratedNewChildId != null) {
    for (final child in children) {
      if (child.id == migratedNewChildId) return AsyncData(child);
    }
  }

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
