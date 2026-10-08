import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../domain/apple_account_link_outcome.dart';
import '../domain/sign_in_outcome.dart';
import 'firebase_auth_repository.dart';

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

  Future<SignInOutcome> signInWithGoogle();

  /// Apple's own identity provider.
  ///
  /// Offered on iOS only. App Store review guideline 4.8 requires an
  /// equivalent Sign in with Apple wherever a third-party sign-in is
  /// offered, and the Google button above makes that apply to this app.
  Future<SignInOutcome> signInWithApple();

  /// Sends a reset link. Succeeds even for an unknown address, so the screen
  /// can't be used to discover which e-mails have accounts.
  Future<void> sendPasswordReset(String email);

  Future<void> sendEmailVerification();

  /// Reloads the current Firebase user and refreshes the ID token so server
  /// callables receive the latest `email_verified` claim.
  Future<bool> refreshEmailVerification();

  String? get currentUserEmail;

  bool get requiresEmailVerification;

  Future<void> signOut();

  /// Firebase UID when signed in with Firebase, null otherwise.
  String? get currentUserId;
}

/// Optional capability for a signed-in parent to attach an Apple identity to
/// the current Firebase UID. It is separate from sign-in so providers that do
/// not support linking do not gain implicit account-merging behavior.
abstract interface class AppleAccountLinkRepository {
  Future<AppleAccountLinkOutcome> linkAppleAccount();
}

class FakeAuthRepository implements AuthRepository, AppleAccountLinkRepository {
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
  }) => Future.delayed(_latency);

  // Demo mode has no accounts to be returning to, so a provider tap shows
  // the path this work exists for: the full onboarding a new parent gets.
  @override
  Future<SignInOutcome> signInWithGoogle() async {
    await Future<void>.delayed(_latency);
    return SignInOutcome.created;
  }

  @override
  Future<SignInOutcome> signInWithApple() async {
    await Future<void>.delayed(_latency);
    return SignInOutcome.created;
  }

  @override
  Future<AppleAccountLinkOutcome> linkAppleAccount() async =>
      AppleAccountLinkOutcome.linked;

  @override
  Future<void> sendPasswordReset(String email) => Future.delayed(_latency);

  @override
  Future<void> sendEmailVerification() => Future<void>.delayed(_latency);

  @override
  Future<bool> refreshEmailVerification() async => true;

  @override
  Future<void> signOut() => Future.delayed(_latency);

  @override
  String? get currentUserId => null;

  @override
  String? get currentUserEmail => null;

  @override
  bool get requiresEmailVerification => false;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (AppConfig.useFirebase) {
    return ref.watch(firebaseAuthRepositoryProvider);
  }
  return const FakeAuthRepository();
});
