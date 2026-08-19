import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Authentication boundary. The MVP ships with a local fake so the full
/// product flow works offline; swap [authRepositoryProvider] for a real
/// implementation (Firebase Auth, custom backend...) without touching UI.
abstract interface class AuthRepository {
  Future<void> signIn({required String email, required String password});

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<void> signInWithGoogle();
}

class FakeAuthRepository implements AuthRepository {
  const FakeAuthRepository();

  static const _latency = Duration(milliseconds: 350);

  @override
  Future<void> signIn({required String email, required String password}) =>
      Future.delayed(_latency);

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) =>
      Future.delayed(_latency);

  @override
  Future<void> signInWithGoogle() => Future.delayed(_latency);
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const FakeAuthRepository(),
);
