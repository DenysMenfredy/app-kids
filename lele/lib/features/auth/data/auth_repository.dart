import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import 'firebase_auth_repository.dart';

/// Thrown by repositories with a message safe to show the user (pt-BR).
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Authentication boundary. Local mode ships a fake so the full product
/// flow works offline; Firebase mode talks to Firebase Auth (the backend's
/// canonical identity, spec §3).
abstract interface class AuthRepository {
  Future<void> signIn({required String email, required String password});

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<void> signInWithGoogle();

  /// Sends a reset link. Succeeds even for an unknown address, so the screen
  /// can't be used to discover which e-mails have accounts.
  Future<void> sendPasswordReset(String email);

  Future<void> signOut();

  /// Firebase UID when signed in with Firebase, null otherwise.
  String? get currentUserId;
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

  @override
  Future<void> sendPasswordReset(String email) => Future.delayed(_latency);

  @override
  Future<void> signOut() => Future.delayed(_latency);

  @override
  String? get currentUserId => null;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (AppConfig.useFirebase) {
    return ref.watch(firebaseAuthRepositoryProvider);
  }
  return const FakeAuthRepository();
});
