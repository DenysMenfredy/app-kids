import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../learning/application/journey_provider.dart';
import '../../session/application/child_provider.dart';
import '../../session/application/session_controller.dart';
import '../data/lesson_repository.dart';
import '../domain/lesson.dart';
import '../domain/lesson_recovery.dart';
import 'lesson_session_controller.dart';

/// Content for one lesson, cached for the whole run of that lesson: the
/// activities hand off to each other, and a dropped connection mid-lesson
/// must not strand the child on a spinner.
final lessonContentProvider = FutureProvider.family<LessonContent, String>((
  ref,
  lessonId,
) {
  ref.keepAlive();
  if (AppConfig.useFirebase) {
    ref.watch(sessionStorageScopeProvider);
    ref.watch(activeChildIdProvider);
  }
  return ref.watch(lessonRepositoryProvider).loadLesson(lessonId);
});

/// Content for the lesson the child is currently on. Forwards the cached
/// [AsyncValue] without adding another async hop, so moving between
/// activities never flashes a loading state.
final currentLessonContentProvider = Provider<AsyncValue<LessonContent>>(
  (ref) => ref.watch(
    lessonContentProvider(
      ref.watch(lessonRunProvider)?.lessonId ??
          ref.watch(currentLessonIdProvider),
    ),
  ),
);

final lessonIntroContentProvider =
    FutureProvider.autoDispose<
      ({LessonContent lesson, PendingLesson? pending})
    >((ref) async {
      final pending = await ref.watch(pendingLessonProvider.future);
      if (!ref.mounted) throw StateError('Lesson scope changed');
      final lessonId =
          pending?.lessonId ?? ref.watch<String>(currentLessonIdProvider);
      ref.invalidate(lessonContentProvider(lessonId));
      final lesson = await ref.watch(lessonContentProvider(lessonId).future);
      return (lesson: lesson, pending: pending);
    });
