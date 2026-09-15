import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/features/auth/data/auth_repository.dart';
import 'package:lele/features/auth/domain/credentials.dart';
import 'package:lele/features/session/application/parent_provider.dart';
import 'package:lele/features/session/application/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('validateEmail', () {
    test('accepts an ordinary address', () {
      expect(validateEmail('camila@example.com'), isNull);
      expect(validateEmail('  camila@example.com  '), isNull);
      expect(validateEmail('c.silva+lele@mail.example.br'), isNull);
    });

    test('rejects what a parent would plausibly mistype', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('camila'), isNotNull);
      expect(validateEmail('camila@'), isNotNull);
      expect(validateEmail('camila@example'), isNotNull);
      expect(validateEmail('camila @example.com'), isNotNull);
    });

    test('says which problem it is, in pt-BR', () {
      expect(validateEmail(''), 'Informe seu e-mail.');
      expect(validateEmail('nope'), 'Esse e-mail não parece certo.');
    });
  });

  group('validatePassword', () {
    test('accepts a password at the backend minimum', () {
      expect(validatePassword('a' * minimumPasswordLength), isNull);
    });

    test('rejects an empty or too-short password', () {
      expect(validatePassword(''), 'Informe sua senha.');
      expect(
        validatePassword('a' * (minimumPasswordLength - 1)),
        contains('$minimumPasswordLength'),
      );
    });

    test('never trims — spaces are legitimate characters', () {
      expect(validatePassword('   a  '), isNull);
    });
  });

  group('validateName', () {
    test('accepts a real name', () {
      expect(validateName('Camila'), isNull);
      expect(validateName('  Ana Paula '), isNull);
    });

    test('rejects blank or one-letter input', () {
      expect(validateName(''), 'Informe seu nome.');
      expect(validateName('   '), 'Informe seu nome.');
      expect(validateName('C'), 'Nome muito curto.');
    });
  });

  group('parent name (local mode)', () {
    Future<ProviderContainer> makeContainer() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('follows the name given at registration', () async {
      final container = await makeContainer();
      container.read(sessionProvider.notifier).setParentName('Camila');
      expect(container.read(parentNameProvider), 'Camila');
    });

    test('trims what was typed', () async {
      final container = await makeContainer();
      container.read(sessionProvider.notifier).setParentName('  Camila  ');
      expect(container.read(parentNameProvider), 'Camila');
    });

    test('survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      first.read(sessionProvider.notifier).setParentName('Camila');
      first.dispose();

      final second = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(second.dispose);
      expect(second.read(parentNameProvider), 'Camila');
    });
  });

  group('FakeAuthRepository', () {
    test('supports the whole sign-in surface the screens call', () async {
      const repository = FakeAuthRepository();
      await expectLater(
        repository.signIn(email: 'a@b.co', password: 'segredo'),
        completes,
      );
      await expectLater(repository.sendPasswordReset('a@b.co'), completes);
      await expectLater(repository.signOut(), completes);
    });
  });
}
