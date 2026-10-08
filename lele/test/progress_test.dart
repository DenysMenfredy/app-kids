import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/features/lesson/data/lesson_sync_service.dart';
import 'package:lele/features/lesson/domain/lesson_reward.dart';
import 'package:lele/features/session/application/demo_progress_controller.dart';
import 'package:lele/features/session/application/progress_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> makeContainer() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LessonReward', () {
    test('parses what the backend granted', () {
      final reward = LessonReward.fromMap(const {
        'awarded': true,
        'xpEarned': 50,
        'coinsEarned': 10,
        'xp': 170,
        'coins': 55,
        'streak': 4,
      });
      expect(reward.awarded, isTrue);
      expect(reward.xpEarned, 50);
      expect(reward.xp, 170);
      expect(reward.streak, 4);
    });

    test('a replayed lesson reports no new reward', () {
      final reward = LessonReward.fromMap(const {
        'awarded': false,
        'xpEarned': 0,
        'coinsEarned': 0,
        'xp': 170,
        'coins': 55,
        'streak': 4,
      });
      expect(reward.awarded, isFalse);
      expect(reward.xpEarned, 0);
      // Totals still come back so the UI stays in sync.
      expect(reward.xp, 170);
    });

    test('missing fields read as zero rather than crashing', () {
      final reward = LessonReward.fromMap(const {});
      expect(reward.awarded, isFalse);
      expect(reward.xpEarned, 0);
      expect(reward.streak, 0);
    });
  });

  group('progressProvider (local mode)', () {
    test('mirrors the on-device demo totals', () async {
      final container = await makeContainer();
      final demo = container.read(demoProgressProvider);
      final progress = container.read(progressProvider);

      expect(progress, demo);
      expect(progress.xp, DemoProgress.seed.xp);
    });

    test('what it shows is what is on the device', () async {
      final container = await makeContainer();
      container.read(demoProgressProvider.notifier).completeLesson();

      final shown = container.read(progressProvider);
      final prefs = container.read(sharedPreferencesProvider);

      // The reported bug in its simplest form: the number on screen and the
      // number in local storage have to be the same number.
      expect(prefs.getInt('session.xp'), shown.xp);
      expect(prefs.getInt('session.coins'), shown.coins);
      expect(prefs.getInt('session.streak'), shown.streak);
    });

    test('follows the local reward when a lesson completes', () async {
      final container = await makeContainer();
      final before = container.read(progressProvider);

      container.read(demoProgressProvider.notifier).completeLesson();

      final after = container.read(progressProvider);
      expect(after.xp, before.xp + 50);
      expect(after.coins, before.coins + 10);
      expect(after.streak, before.streak + 1);
    });

    test('demo lesson sync reports the standard reward', () async {
      const service = NoopLessonSyncService();
      final reward = await service.lessonCompleted('lesson_008', 'child_1');
      expect(reward, LessonReward.demo);
      expect(reward?.xpEarned, 50);
      expect(reward?.coinsEarned, 10);
    });
  });
}
