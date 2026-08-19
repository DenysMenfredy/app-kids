import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/features/session/application/session_controller.dart';
import 'package:lele/features/session/domain/child_profile.dart';
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

  group('SessionController', () {
    test('starts with the default session', () async {
      final container = await makeContainer();
      final state = container.read(sessionProvider);
      expect(state.parentName, 'Ana');
      expect(state.child.name, 'Sofia');
      expect(state.xp, 120);
      expect(state.coins, 45);
      expect(state.streak, 3);
    });

    test('completeLesson grants XP, coins and streak', () async {
      final container = await makeContainer();
      container.read(sessionProvider.notifier).completeLesson();
      final state = container.read(sessionProvider);
      expect(state.xp, 170);
      expect(state.coins, 55);
      expect(state.streak, 4);
    });

    test('persists child profile across container restarts', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      container.read(sessionProvider.notifier).saveChildProfile(
            const ChildProfile(name: 'Miguel', age: 6, avatar: ChildAvatar.teal),
          );
      container.dispose();

      final restarted = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(restarted.dispose);
      final child = restarted.read(sessionProvider).child;
      expect(child.name, 'Miguel');
      expect(child.age, 6);
      expect(child.avatar, ChildAvatar.teal);
    });

    test('ignores blank parent name', () async {
      final container = await makeContainer();
      container.read(sessionProvider.notifier).setParentName('   ');
      expect(container.read(sessionProvider).parentName, 'Ana');
    });
  });
}
