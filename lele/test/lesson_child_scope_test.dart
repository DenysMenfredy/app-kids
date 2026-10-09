import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/features/learning/application/journey_provider.dart';
import 'package:lele/features/lesson/application/lesson_session_controller.dart';
import 'package:lele/features/lesson/data/lesson_sync_service.dart';
import 'package:lele/features/lesson/domain/lesson_reward.dart';
import 'package:lele/features/session/application/child_provider.dart';
import 'package:lele/features/session/application/session_controller.dart';
import 'package:lele/features/session/domain/child_profile.dart';
import 'package:lele/features/session/domain/child_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingLessonSyncService implements LessonSyncService {
  String? startedLessonId;
  String? attemptedLessonId;
  String? completedLessonId;
  int completions = 0;
  final actions = <String>[];
  @override
  Future<void> sessionLifecycle(
    String lessonId,
    String childId,
    String action,
  ) async {
    actions.add(action);
  }

  String? startedChildId;
  String? attemptedChildId;
  String? completedChildId;

  @override
  Future<void> lessonStarted(String lessonId, String childId) async {
    startedChildId = childId;
    startedLessonId = lessonId;
  }

  @override
  Future<void> activityAttempt(
    String lessonId,
    String childId,
    String activityId,
    Map<String, Object?> response,
  ) async {
    attemptedChildId = childId;
    attemptedLessonId = lessonId;
  }

  @override
  Future<LessonReward?> lessonCompleted(String lessonId, String childId) async {
    completedChildId = childId;
    completedLessonId = lessonId;
    completions++;
    return LessonReward.demo;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a lesson run remains scoped to its starting child after a switch',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final sync = _RecordingLessonSyncService();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          lessonSyncServiceProvider.overrideWithValue(sync),
        ],
      );
      addTearDown(container.dispose);

      final sessions = container.read(sessionProvider.notifier);
      sessions.selectChild(
        const ChildRecord(
          id: 'child-a',
          profile: ChildProfile(
            name: 'Lia',
            age: 4,
            avatar: ChildAvatar.orange,
          ),
        ),
      );
      final lesson = container.read(lessonSessionProvider);
      lesson.start();
      final startingLesson = sync.startedLessonId!;
      container.read(demoLessonProvider.notifier).completed(startingLesson);
      lesson.setForeground(false);
      lesson.setForeground(true);

      sessions.selectChild(
        const ChildRecord(
          id: 'child-b',
          profile: ChildProfile(name: 'Caio', age: 6, avatar: ChildAvatar.teal),
        ),
      );
      lesson.recordAttempt('activity_1', const {'selectedLabel': 'A'});
      final completion = lesson.complete();
      expect(identical(lesson.complete(), completion), isTrue);
      await completion;

      expect(sync.startedChildId, 'child-a');
      expect(sync.attemptedChildId, 'child-a');
      expect(sync.completedChildId, 'child-a');
      expect(sync.attemptedLessonId, startingLesson);
      expect(sync.completedLessonId, startingLesson);
      expect(sync.completions, 1);
      expect(sync.actions, ['pause', 'resume']);
      expect(container.read(activeChildIdProvider), 'child-b');
    },
  );
}
