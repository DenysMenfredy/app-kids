import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/features/lesson/application/lesson_session_controller.dart';
import 'package:lele/features/lesson/data/lesson_sync_service.dart';
import 'package:lele/features/lesson/domain/lesson_reward.dart';
import 'package:lele/features/session/application/child_provider.dart';
import 'package:lele/features/session/application/session_controller.dart';
import 'package:lele/features/session/domain/child_profile.dart';
import 'package:lele/features/session/domain/child_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingLessonSyncService implements LessonSyncService {
  String? startedChildId;
  String? attemptedChildId;
  String? completedChildId;

  @override
  Future<void> lessonStarted(String lessonId, String childId) async {
    startedChildId = childId;
  }

  @override
  Future<void> activityAttempt(
    String lessonId,
    String childId,
    String activityId,
    Map<String, Object?> response,
  ) async {
    attemptedChildId = childId;
  }

  @override
  Future<LessonReward?> lessonCompleted(String lessonId, String childId) async {
    completedChildId = childId;
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

      sessions.selectChild(
        const ChildRecord(
          id: 'child-b',
          profile: ChildProfile(name: 'Caio', age: 6, avatar: ChildAvatar.teal),
        ),
      );
      lesson.recordAttempt('activity_1', const {'selectedLabel': 'A'});
      await lesson.complete();

      expect(sync.startedChildId, 'child-a');
      expect(sync.attemptedChildId, 'child-a');
      expect(sync.completedChildId, 'child-a');
      expect(container.read(activeChildIdProvider), 'child-b');
    },
  );
}
