import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/learning_module.dart';

/// Streams `currentLessonId` from the child profile — the field
/// submitAssessment writes when it places the child (ADR 0003). Null until
/// the profile exists or an assessment has been submitted.
final remoteCurrentLessonIdProvider = StreamProvider<String?>((ref) {
  if (!AppConfig.useFirebase) return Stream.value(null);
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);

  return auth.authStateChanges().asyncExpand((user) {
    if (user == null) return Stream<String?>.value(null);
    return firestore
        .doc('users/${user.uid}/children/${AppConfig.primaryChildId}')
        .snapshots()
        .map((snapshot) => snapshot.data()?['currentLessonId'] as String?);
  });
});

/// The lesson the child should play next.
///
/// With the backend on, this is the placement it computed; a child who
/// hasn't been placed yet starts at the first lesson. Demo mode uses the
/// prototype's lesson so the journey looks like the original design.
/// While the first snapshot is in flight the journey briefly shows the
/// opening module, the same way progress starts at zero.
final currentLessonIdProvider = Provider<String>((ref) {
  if (!AppConfig.useFirebase) return AppConfig.demoLessonId;
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
