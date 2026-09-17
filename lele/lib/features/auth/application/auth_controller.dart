import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../session/application/session_controller.dart';
import '../data/auth_repository.dart';
import '../domain/sign_in_outcome.dart';

/// What the sign-in and registration screens actually do.
///
/// The screens used to reach past this layer and drive [AuthRepository]
/// themselves, which meant the one step that is not a repository call —
/// recording the parent's name for the dashboard greeting — sat in a widget,
/// where the next screen to offer registration would have had to remember
/// it. Failures still surface as [AuthFailure] for the screen to present.
class AuthController {
  const AuthController(this._ref);

  final Ref _ref;

  AuthRepository get _repository => _ref.read(authRepositoryProvider);

  Future<void> signIn({required String email, required String password}) =>
      _repository.signIn(email: email, password: password);

  /// Registers the parent and records the name they gave.
  ///
  /// The name is what the dashboard greets them by, here and on every device
  /// they later sign in from, so it is part of registering rather than a
  /// step the caller has to remember.
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await _repository.signUp(name: name, email: email, password: password);
    _ref.read(sessionProvider.notifier).setParentName(name);
  }

  Future<SignInOutcome> signInWithGoogle() => _repository.signInWithGoogle();

  Future<SignInOutcome> signInWithApple() => _repository.signInWithApple();

  Future<void> sendPasswordReset(String email) =>
      _repository.sendPasswordReset(email);

  Future<void> signOut() => _repository.signOut();
}

final authControllerProvider = Provider<AuthController>(AuthController.new);
