import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/apple_account_link_outcome.dart';
import '../domain/auth_failure.dart';
import '../domain/sign_in_outcome.dart';
import 'auth_repository.dart';
import 'google_identity_service.dart';

/// Firebase Auth implementation (spec §3). The backend's onUserCreated
/// trigger bootstraps the Firestore profile when an account is created;
/// this class only handles identity.
class FirebaseAuthRepository
    implements AuthRepository, AppleAccountLinkRepository {
  FirebaseAuthRepository(this._auth, {GoogleIdentityService? googleIdentity})
    : _googleIdentity = googleIdentity ?? NativeGoogleIdentityService();

  final FirebaseAuth _auth;
  final GoogleIdentityService _googleIdentity;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  String? get currentUserEmail => _auth.currentUser?.email;

  @override
  bool get requiresEmailVerification {
    final user = _auth.currentUser;
    return user != null &&
        user.providerData.any(
          (provider) => provider.providerId == 'password',
        ) &&
        !user.emailVerified;
  }

  @override
  Future<void> signIn({required String email, required String password}) {
    return _guard(() async {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    });
  }

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    return _guard(() async {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (name.trim().isNotEmpty) {
        await credential.user?.updateDisplayName(name.trim());
      }
    });
  }

  @override
  Future<SignInOutcome> signInWithGoogle() async {
    try {
      final UserCredential credential;
      if (kIsWeb) {
        credential = await _auth.signInWithPopup(_googleProvider());
      } else {
        final token = await _googleIdentity.authenticate();
        if (token == null) return SignInOutcome.cancelled;
        credential = await _auth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: token),
        );
      }
      // Only Firebase's result decides UID/new-account status. Never look up,
      // link or merge another family by the Google account's email.
      return _outcomeOf(credential);
    } on FirebaseAuthException catch (error) {
      if (isSignInCancellation(error.code)) return SignInOutcome.cancelled;
      throw AuthFailure(authErrorMessage(error.code));
    }
  }

  /// Google's web-popup provider, configured rather than bare.
  ///
  /// `prompt: select_account` is the part that matters on a family device.
  /// Without it Google silently reuses whichever account signed in last, so
  /// the second parent to try gets handed the first parent's identity with
  /// no chooser and no way to tell. The scopes are the two Google asks you
  /// to keep to: enough to name and contact the parent, nothing more.
  GoogleAuthProvider _googleProvider() => GoogleAuthProvider()
    ..addScope('email')
    ..addScope('profile')
    ..setCustomParameters({'prompt': 'select_account'});

  /// Whether Firebase had to create the account to complete this sign-in.
  SignInOutcome _outcomeOf(UserCredential credential) =>
      (credential.additionalUserInfo?.isNewUser ?? false)
      ? SignInOutcome.created
      : SignInOutcome.returning;

  @override
  Future<SignInOutcome> signInWithApple() {
    // Firebase drives the native ASAuthorization sheet on iOS and manages
    // the nonce. Unlike Google, Apple supports signInWithProvider directly.
    //
    // Unlike Google, this does NOT reliably resolve to an existing account.
    // A parent who picks Apple's "Hide My Email" arrives with a relay
    // address that matches nothing, and Firebase correctly mints a new uid
    // — a new family, with premium inactive. See ADR 0005 for the explicit
    // account-linking path; email-based account merging is never attempted.
    return _providerSignIn(AppleAuthProvider());
  }

  @override
  Future<AppleAccountLinkOutcome> linkAppleAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('Entre novamente para conectar sua conta Apple.');
    }
    if (user.providerData.any(
      (provider) => provider.providerId == 'apple.com',
    )) {
      return AppleAccountLinkOutcome.alreadyLinked;
    }

    try {
      await user.linkWithProvider(AppleAuthProvider());
      return AppleAccountLinkOutcome.linked;
    } on FirebaseAuthException catch (e) {
      if (isSignInCancellation(e.code)) {
        return AppleAccountLinkOutcome.cancelled;
      }
      if (e.code == 'provider-already-linked') {
        return AppleAccountLinkOutcome.alreadyLinked;
      }
      throw AuthFailure(appleLinkErrorMessage(e.code));
    }
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return _guard(() async {
      try {
        await _auth.sendPasswordResetEmail(email: email.trim());
      } on FirebaseAuthException catch (e) {
        // Don't let the screen reveal whether an account exists; anything
        // other than a malformed address is reported as sent.
        if (e.code == 'user-not-found') return;
        rethrow;
      }
    });
  }

  @override
  Future<void> sendEmailVerification() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('Entre novamente para confirmar seu e-mail.');
    }
    await user.sendEmailVerification();
  });

  @override
  Future<bool> refreshEmailVerification() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshedUser = _auth.currentUser;
    if (refreshedUser == null) return false;
    await refreshedUser.getIdToken(true);
    return refreshedUser.emailVerified;
  });

  @override
  Future<void> signOut() async {
    try {
      if (!kIsWeb) await _googleIdentity.signOut();
    } finally {
      // Google cleanup must never prevent signing out the Firebase family UID.
      await _auth.signOut();
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(authErrorMessage(e.code));
    }
  }

  /// Runs a provider sheet, treating dismissal as an outcome rather than a
  /// failure.
  ///
  /// This sits outside [_guard] on purpose: [_guard] turns every
  /// FirebaseAuthException into a message for the parent to read, and
  /// "you closed the window" is not a message anyone needs.
  Future<SignInOutcome> _providerSignIn(AuthProvider provider) async {
    try {
      final credential = await _auth.signInWithProvider(provider);
      return _outcomeOf(credential);
    } on FirebaseAuthException catch (e) {
      if (isSignInCancellation(e.code)) return SignInOutcome.cancelled;
      throw AuthFailure(authErrorMessage(e.code));
    }
  }
}

/// Maps Firebase Auth error codes to friendly pt-BR messages.
/// Sign-in failures deliberately avoid revealing whether the account exists.
/// Codes the platforms use when the parent dismisses the provider sheet.
///
/// They disagree on spelling — and on the number of l's in "cancelled" —
/// so this is a set rather than a comparison.
const signInCancellationCodes = {
  'web-context-canceled',
  'web-context-cancelled',
  'popup-closed-by-user',
  'cancelled-popup-request',
  'user-canceled',
  'user-cancelled',
  'canceled',
  'sign_in_canceled',
  'ERROR_ABORTED_BY_USER',
};

/// Backing out of the Google sheet is a decision, not an error.
bool isSignInCancellation(String code) =>
    signInCancellationCodes.contains(code);

String authErrorMessage(String code) {
  switch (code) {
    case 'account-exists-with-different-credential':
      // The common Google collision: registered with e-mail, now tapping
      // Google. Naming the fix beats "something went wrong".
      return 'Este e-mail já tem uma conta. Entre com e-mail e senha.';
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return 'E-mail ou senha incorretos.';
    case 'invalid-email':
      return 'E-mail inválido.';
    case 'email-already-in-use':
      return 'Este e-mail já tem uma conta. Tente entrar.';
    case 'weak-password':
      return 'Senha muito curta — use pelo menos 6 caracteres.';
    case 'user-disabled':
      return 'Esta conta foi desativada. Fale com o suporte.';
    case 'too-many-requests':
      return 'Muitas tentativas. Aguarde um pouco e tente de novo.';
    case 'network-request-failed':
      return 'Sem conexão. Verifique sua internet.';
    case 'operation-not-allowed':
    case 'configuration-not-found':
      return 'Esta forma de acesso ainda não está configurada para este app.';
    default:
      return 'Não foi possível entrar agora. Tente novamente.';
  }
}

String appleLinkErrorMessage(String code) {
  switch (code) {
    case 'credential-already-in-use':
    case 'account-exists-with-different-credential':
    case 'email-already-in-use':
      return 'Este Apple ID já está conectado a outra conta do Lelê. Saia e '
          'entre pela conta que já usa Apple; as contas não são unidas '
          'automaticamente.';
    case 'requires-recent-login':
      return 'Por segurança, entre novamente antes de conectar sua conta Apple.';
    case 'network-request-failed':
      return 'Sem conexão. Verifique sua internet e tente novamente.';
    case 'operation-not-allowed':
      return 'O acesso com Apple ainda não está configurado para este app.';
    default:
      return 'Não foi possível conectar sua conta Apple agora. Tente novamente.';
  }
}

final firebaseAuthRepositoryProvider = Provider<FirebaseAuthRepository>(
  (ref) => FirebaseAuthRepository(ref.watch(firebaseAuthProvider)),
);
