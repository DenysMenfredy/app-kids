import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import 'auth_repository.dart';

/// Firebase Auth implementation (spec §3). The backend's onUserCreated
/// trigger bootstraps the Firestore profile when an account is created;
/// this class only handles identity.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

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
  Future<void> signInWithGoogle() {
    return _guard(() async {
      // signInWithProvider drives the native Google flow on iOS/Android
      // without the google_sign_in package. Firebase Auth links providers
      // that share a verified email to the same UID (spec §3).
      await _auth.signInWithProvider(GoogleAuthProvider());
    });
  }

  @override
  Future<void> signOut() => _auth.signOut();

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(authErrorMessage(e.code));
    }
  }
}

/// Maps Firebase Auth error codes to friendly pt-BR messages.
/// Sign-in failures deliberately avoid revealing whether the account exists.
String authErrorMessage(String code) {
  switch (code) {
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
    default:
      return 'Não foi possível entrar agora. Tente novamente.';
  }
}

final firebaseAuthRepositoryProvider = Provider<FirebaseAuthRepository>(
  (ref) => FirebaseAuthRepository(ref.watch(firebaseAuthProvider)),
);
