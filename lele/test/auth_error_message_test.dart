import 'package:flutter_test/flutter_test.dart';
import 'package:lele/features/auth/data/firebase_auth_repository.dart';

void main() {
  group('authErrorMessage', () {
    test('maps credential failures without revealing account existence', () {
      const expected = 'E-mail ou senha incorretos.';
      expect(authErrorMessage('invalid-credential'), expected);
      expect(authErrorMessage('wrong-password'), expected);
      expect(authErrorMessage('user-not-found'), expected);
    });

    test('gives actionable messages for recoverable problems', () {
      expect(
        authErrorMessage('email-already-in-use'),
        'Este e-mail já tem uma conta. Tente entrar.',
      );
      expect(
        authErrorMessage('weak-password'),
        'Senha muito curta — use pelo menos 6 caracteres.',
      );
      expect(authErrorMessage('network-request-failed'),
          'Sem conexão. Verifique sua internet.');
    });

    test('falls back to a generic message for unknown codes', () {
      expect(
        authErrorMessage('something-new-from-firebase'),
        'Não foi possível entrar agora. Tente novamente.',
      );
    });

    test('never returns an empty message', () {
      const codes = [
        'invalid-credential',
        'invalid-email',
        'email-already-in-use',
        'weak-password',
        'user-disabled',
        'too-many-requests',
        'network-request-failed',
        'unknown',
      ];
      for (final code in codes) {
        expect(authErrorMessage(code), isNotEmpty, reason: code);
      }
    });
  });
}
