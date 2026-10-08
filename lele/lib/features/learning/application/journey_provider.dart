import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/storage/local_storage.dart';
import '../../session/application/child_provider.dart';
import '../domain/learning_module.dart';

/// Streams `currentLessonId` from the child profile — the field
/// submitAssessment writes when it places the child (ADR 0003). Null until
/// the profile exists or an assessment has been submitted.
final remoteCurrentLessonIdProvider = Provider<AsyncValue<String?>>((ref) {
  if (!AppConfig.useFirebase) return const AsyncData(null);

  final authState = ref.watch(firebaseAuthUserProvider);
  if (authState.isLoading) return const AsyncLoading();
  if (authState.hasError) {
    return AsyncError(authState.error!, authState.stackTrace!);
  }
  final user = authState.value;
  if (user == null) return const AsyncData(null);

  final childId = ref.watch(activeChildIdProvider);
  return ref.watch(
    _currentLessonForChildProvider((uid: user.uid, childId: childId)),
  );
});

final _currentLessonForChildProvider = StreamProvider.autoDispose
    .family<String?, ({String uid, String childId})>((ref, scope) {
      final firestore = ref.watch(firestoreProvider);
      return firestore
          .doc('users/${scope.uid}/children/${scope.childId}')
          .snapshots()
          .map((snapshot) => snapshot.data()?['currentLessonId'] as String?);
    });

/// Where the child is in demo mode.
///
/// With the backend on, completeLesson moves them on and the profile stream
/// reports it. Offline there is nobody to do that, so the position is kept
/// on the device — otherwise finishing a lesson would hand back the same one
/// forever.
class DemoLessonController extends Notifier<String> {
  static const _key = 'learning.demoLessonId';

  @override
  String build() {
    return ref.watch(sharedPreferencesProvider).getString(_key) ??
        AppConfig.demoLessonId;
  }

  /// Advances past [lessonId], but only when that is where the child is —
  /// replaying an earlier lesson must not skip them forward.
  void completed(String lessonId) {
    if (AppConfig.useFirebase || state != lessonId) return;
    final next = nextLessonId(lessonId);
    if (next == null) return; // end of the curriculum
    state = next;
    ref.read(sharedPreferencesProvider).setString(_key, next);
  }
}

final demoLessonProvider = NotifierProvider<DemoLessonController, String>(
  DemoLessonController.new,
);

/// The lesson the child should play next.
///
/// With the backend on, this is the placement it computed; a child who
/// hasn't been placed yet starts at the first lesson. Demo mode uses the
/// prototype's lesson so the journey looks like the original design.
/// While the first snapshot is in flight the journey briefly shows the
/// opening module, the same way progress starts at zero.
final currentLessonIdProvider = Provider<String>((ref) {
  if (!AppConfig.useFirebase) return ref.watch(demoLessonProvider);
  return ref.watch(remoteCurrentLessonIdProvider).value ??
      curriculum.first.firstLessonId;
});

/// The journey as the child sees it, anchored on their current lesson.
final journeyProvider = Provider<List<LearningModule>>(
  (ref) => resolveJourney(ref.watch(currentLessonIdProvider)),
);

/// The module the child is working through. [resolveJourney] guarantees
/// exactly one, so this never throws.
final currentModuleProvider = Provider<LearningModule>(
  (ref) => ref
      .watch(journeyProvider)
      .firstWhere((module) => module.status == ModuleStatus.current),
);

/// Position of the current lesson inside the whole curriculum, for display
/// ("LIÇÃO 8 · SONS E RIMAS").
final currentLessonNumberProvider = Provider<int>(
  (ref) =>
      lessonNumberOf(ref.watch(currentLessonIdProvider)) ??
      curriculum.first.firstLessonNumber,
);
