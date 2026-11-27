import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/features/lesson/application/lesson_stats_controller.dart';
import 'package:lele/features/lesson/data/pending_lesson_store.dart';
import 'package:lele/features/lesson/domain/lesson_recovery.dart';
import 'package:lele/features/notifications/application/notification_controller.dart';
import 'package:lele/features/notifications/domain/notification_ports.dart';
import 'package:lele/features/session/application/session_controller.dart';
import 'package:lele/features/session/domain/child_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentNotificationPlatform implements NotificationPlatform {
  @override
  bool get supported => true;

  @override
  String get platform => 'test';

  @override
  Future<bool> allowed() async => true;

  @override
  Future<void> clear() async {}

  @override
  void dispose() {}

  @override
  Future<void> initialize({
    required void Function() onOpen,
    required void Function() onTokenRefresh,
  }) async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> showDemo() async {}

  @override
  Future<void> stopRemote() async {}

  @override
  Future<String?> token() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('account switch keeps parent name and child cache separated', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final parentA = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionStorageScopeProvider.overrideWithValue('uid-a'),
      ],
    );
    addTearDown(parentA.dispose);
    parentA.read(sessionProvider.notifier).setParentName('Responsável A');
    await parentA
        .read(sessionProvider.notifier)
        .saveChildProfile(
          const ChildProfile(name: 'Lia', age: 4, avatar: ChildAvatar.teal),
        );

    final parentB = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionStorageScopeProvider.overrideWithValue('uid-b'),
      ],
    );
    addTearDown(parentB.dispose);

    expect(parentB.read(sessionProvider).parentName, 'Ana');
    expect(parentB.read(sessionProvider).child.name, 'Sofia');
    expect(parentB.read(sessionProvider).childId, 'primary');

    final returningA = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionStorageScopeProvider.overrideWithValue('uid-a'),
      ],
    );
    addTearDown(returningA.dispose);
    expect(returningA.read(sessionProvider).parentName, 'Responsável A');
    expect(returningA.read(sessionProvider).child.name, 'Lia');
  });

  test('lesson statistics start empty for the next parent', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final parentA = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionStorageScopeProvider.overrideWithValue('uid-a'),
      ],
    );
    addTearDown(parentA.dispose);
    parentA.read(lessonStatsProvider.notifier)
      ..start()
      ..recordCorrect()
      ..recordWrong();
    expect(parentA.read(lessonStatsProvider).attempts, 2);

    final parentB = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionStorageScopeProvider.overrideWithValue('uid-b'),
      ],
    );
    addTearDown(parentB.dispose);
    expect(parentB.read(lessonStatsProvider).attempts, 0);
    expect(parentB.read(lessonStatsProvider).correctAnswers, 0);
  });

  test('pending lesson recovery is namespaced by parent and child', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 11, 27, 12);
    final storeA = PendingLessonStore(prefs, 'uid-a', now: () => now);
    final storeB = PendingLessonStore(prefs, 'uid-b', now: () => now);
    final pending = PendingLesson(
      childId: 'child-a',
      lessonId: 'lesson_010',
      requestId: 'request-1',
      createdAtMillis: now.millisecondsSinceEpoch,
      contentVersion: 1,
      attempts: const [
        PendingLessonAttempt(
          requestId: 'attempt-1',
          activityId: 'activity_1',
          response: {'selectedLabel': 'A'},
        ),
      ],
    );

    await storeA.save(pending);
    expect((await storeA.load('child-a'))?.lessonId, 'lesson_010');

    expect(await storeB.load('child-a'), isNull);
    final storeBOtherChild = PendingLessonStore(prefs, 'uid-b', now: () => now);
    expect(await storeBOtherChild.load('child-b'), isNull);
  });

  test('notification preference is keyed by the signed-in uid', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications.enabled.uid-a', true);

    String? uid = 'uid-a';
    final controller = NotificationController(
      platform: _SilentNotificationPlatform(),
      prefs: prefs,
      currentUid: () => uid,
      remoteEnabled: false,
    );
    addTearDown(controller.dispose);
    expect(controller.enabled, isTrue);

    uid = 'uid-b';
    expect(controller.enabled, isFalse);

    uid = 'uid-a';
    expect(controller.enabled, isTrue);
  });
}
