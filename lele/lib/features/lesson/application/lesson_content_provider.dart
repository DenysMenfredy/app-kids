import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../learning/application/journey_provider.dart';
import '../data/lesson_repository.dart';
import '../domain/lesson.dart';

/// Content for one lesson, cached for the whole run of that lesson: the
/// activities hand off to each other, and a dropped connection mid-lesson
/// must not strand the child on a spinner.
final lessonContentProvider = FutureProvider.family<LessonContent, String>((
  ref,
  lessonId,
) {
  ref.keepAlive();
  return ref.watch(lessonRepositoryProvider).loadLesson(lessonId);
});

/// Content for the lesson the child is currently on. Forwards the cached
/// [AsyncValue] without adding another async hop, so moving between
/// activities never flashes a loading state.
final currentLessonContentProvider = Provider<AsyncValue<LessonContent>>(
  (ref) => ref.watch(lessonContentProvider(ref.watch(currentLessonIdProvider))),
);
