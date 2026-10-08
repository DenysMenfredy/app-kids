import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/progress.dart';
import 'child_provider.dart';
import 'demo_progress_controller.dart';

/// Streams `users/{uid}/gamification/{childId}` — the document only
/// completeLesson writes (ADR 0003). A child who has never finished a
/// lesson has no document yet, which reads as zero.
final remoteProgressProvider = Provider<AsyncValue<Progress>>((ref) {
  if (!AppConfig.useFirebase) return const AsyncData(Progress.zero);

  final authState = ref.watch(firebaseAuthUserProvider);
  if (authState.isLoading) return const AsyncLoading();
  if (authState.hasError) {
    return AsyncError(authState.error!, authState.stackTrace!);
  }
  final user = authState.value;
  if (user == null) return const AsyncData(Progress.zero);

  final childId = ref.watch(activeChildIdProvider);
  return ref.watch(
    _progressForChildProvider((uid: user.uid, childId: childId)),
  );
});

final _progressForChildProvider = StreamProvider.autoDispose
    .family<Progress, ({String uid, String childId})>((ref, scope) {
      final firestore = ref.watch(firestoreProvider);
      return firestore
          .doc('users/${scope.uid}/gamification/${scope.childId}')
          .snapshots()
          .map((snapshot) {
            final data = snapshot.data();
            if (data == null) return Progress.zero;
            return Progress(
              xp: (data['xp'] as num?)?.toInt() ?? 0,
              coins: (data['coins'] as num?)?.toInt() ?? 0,
              streak: (data['streak'] as num?)?.toInt() ?? 0,
            );
          });
    });

/// XP, coins and streak for the UI.
///
/// In Firebase mode these are the backend's numbers — the app displays what
/// it is told and never adds to them locally. Demo mode falls back to the
/// on-device session values so the prototype still works offline.
final progressProvider = Provider<Progress>((ref) {
  if (!AppConfig.useFirebase) return ref.watch(demoProgressProvider);
  // A refresh for the same UID/child keeps its last snapshot to avoid a
  // flicker. Changing UID or child switches to a different family provider,
  // which has no previous account's value to expose.
  return ref.watch(remoteProgressProvider).value ?? Progress.zero;
});
