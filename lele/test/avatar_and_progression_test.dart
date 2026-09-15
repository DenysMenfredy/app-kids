import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/config/app_config.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/features/learning/application/journey_provider.dart';
import 'package:lele/features/learning/domain/learning_module.dart';
import 'package:lele/features/session/application/child_provider.dart';
import 'package:lele/features/session/application/session_controller.dart';
import 'package:lele/features/session/domain/child_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> makeContainer([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('avatar', () {
    test('every avatar has its own colour and a darker mouth', () {
      final colours = ChildAvatar.values.map((a) => a.color).toSet();
      expect(colours, hasLength(ChildAvatar.values.length));
      for (final avatar in ChildAvatar.values) {
        expect(avatar.mouthColor, isNot(avatar.color), reason: avatar.name);
      }
    });

    test('reads back the id the backend stores', () {
      for (final avatar in ChildAvatar.values) {
        expect(childAvatarFromId(avatar.name), avatar);
      }
    });

    test('an unknown or missing id falls back instead of throwing', () {
      expect(childAvatarFromId(null), ChildProfile.defaultProfile.avatar);
      expect(childAvatarFromId('rainbow'), ChildProfile.defaultProfile.avatar);
    });

    test('the chosen avatar reaches the rest of the app', () async {
      final container = await makeContainer();
      // Anything but the default, so a pass can't be the default leaking.
      expect(ChildAvatar.purple, isNot(ChildProfile.defaultProfile.avatar));

      container.read(sessionProvider.notifier).saveChildProfile(
            const ChildProfile(
              name: 'Miguel',
              age: 6,
              avatar: ChildAvatar.purple,
            ),
          );

      final child = container.read(childProvider);
      expect(child.avatar, ChildAvatar.purple);
      expect(child.name, 'Miguel');
      expect(child.age, 6);
    });

    test('the choice survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      first.read(sessionProvider.notifier).saveChildProfile(
            const ChildProfile(name: 'Miguel', age: 6, avatar: ChildAvatar.teal),
          );
      first.dispose();

      final second = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(second.dispose);
      expect(second.read(childProvider).avatar, ChildAvatar.teal);
    });
  });

  group('nextLessonId', () {
    test('steps through the curriculum one lesson at a time', () {
      expect(nextLessonId('lesson_001'), 'lesson_002');
      expect(nextLessonId('lesson_009'), 'lesson_010');
      expect(nextLessonId('lesson_013'), 'lesson_014');
    });

    test('crosses a module boundary without skipping', () {
      // Module 1 ends at lesson_003, module 2 starts at lesson_004.
      expect(nextLessonId('lesson_003'), 'lesson_004');
      expect(moduleForLesson('lesson_004')?.number, 2);
    });

    test('stops at the end of the curriculum', () {
      final last = 'lesson_${curriculum.last.lastLessonNumber.toString().padLeft(3, '0')}';
      expect(nextLessonId(last), isNull);
    });

    test('returns null for an id that is not a lesson', () {
      expect(nextLessonId('nonsense'), isNull);
    });
  });

  group('demo-mode progression', () {
    test('starts on the demo lesson', () async {
      final container = await makeContainer();
      expect(container.read(currentLessonIdProvider), AppConfig.demoLessonId);
    });

    test('finishing the current lesson hands back the next one', () async {
      final container = await makeContainer();
      final started = container.read(currentLessonIdProvider);

      container.read(demoLessonProvider.notifier).completed(started);

      expect(container.read(currentLessonIdProvider), nextLessonId(started));
      expect(container.read(currentLessonIdProvider), isNot(started));
    });

    test('finishing an older lesson does not skip the child forward',
        () async {
      final container = await makeContainer();
      container.read(demoLessonProvider.notifier).completed('lesson_001');
      expect(container.read(currentLessonIdProvider), AppConfig.demoLessonId);
    });

    test('the position survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      final started = first.read(currentLessonIdProvider);
      first.read(demoLessonProvider.notifier).completed(started);
      final advanced = first.read(currentLessonIdProvider);
      first.dispose();

      final second = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(second.dispose);
      expect(second.read(currentLessonIdProvider), advanced);
    });

    test('the journey follows the child as they advance', () async {
      final container = await makeContainer();
      final before = container.read(currentModuleProvider);

      // Walk to the end of the current module.
      var lesson = container.read(currentLessonIdProvider);
      for (var i = 0; i < 10; i++) {
        container.read(demoLessonProvider.notifier).completed(lesson);
        lesson = container.read(currentLessonIdProvider);
      }

      final after = container.read(currentModuleProvider);
      expect(after.number, greaterThan(before.number));
      expect(
        container.read(journeyProvider).where(
              (m) => m.status == ModuleStatus.done,
            ),
        isNotEmpty,
      );
    });
  });
}
