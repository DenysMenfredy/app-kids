import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/storage/local_storage.dart';
import '../domain/account_deletion.dart';

/// Reauthentication and the server-owned deletion request.
///
/// The server decides the status, the reauthentication window and what gets
/// deleted. The app only supplies a bounded request id and a fresh token.
abstract interface class AccountDeletionService {
  bool get supported;
  bool get isPasswordProvider;
  String? get email;
  String? get providerId;

  Future<void> reauthenticateWithPassword(String password);
  Future<void> reauthenticateWithProvider();

  Future<AccountDeletionResult> request(String requestId);

  /// Removes only this parent's cached state; nothing is written back.
  Future<void> clearLocalState();
}

class UnsupportedAccountDeletionService implements AccountDeletionService {
  const UnsupportedAccountDeletionService();

  @override
  bool get supported => false;
  @override
  bool get isPasswordProvider => false;
  @override
  String? get email => null;
  @override
  String? get providerId => null;

  AccountDeletionFailure get _unsupported => const AccountDeletionFailure(
    AccountDeletionFailureCode.unsupportedProvider,
    'A exclusão de conta exige uma conta conectada ao Firebase.',
  );

  @override
  Future<void> reauthenticateWithPassword(String password) async =>
      throw _unsupported;

  @override
  Future<void> reauthenticateWithProvider() async => throw _unsupported;

  @override
  Future<AccountDeletionResult> request(String requestId) async =>
      throw _unsupported;

  @override
  Future<void> clearLocalState() async {}
}

class FirebaseAccountDeletionService implements AccountDeletionService {
  FirebaseAccountDeletionService(this._auth, this._functions, this._prefs);

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final SharedPreferences _prefs;

  User? get _user => _auth.currentUser;

  @override
  bool get supported => true;

  @override
  String? get email => _user?.email;

  /// Password wins when an account has both a password and a provider: it is
  /// the path that works without depending on a native account chooser.
  @override
  String? get providerId {
    final providers = _user?.providerData ?? const <UserInfo>[];
    for (final provider in providers) {
      if (provider.providerId == 'password') return 'password';
    }
    for (final provider in providers) {
      if (provider.providerId == 'google.com' ||
          provider.providerId == 'apple.com') {
        return provider.providerId;
      }
    }
    return providers.isEmpty ? null : providers.first.providerId;
  }

  @override
  bool get isPasswordProvider => providerId == 'password';

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _user;
    final address = user?.email;
    if (user == null || address == null || address.isEmpty) {
      throw const AccountDeletionFailure(
        AccountDeletionFailureCode.reauthRequired,
        'Entre novamente para confirmar sua conta.',
      );
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: address, password: password),
      );
      await user.getIdToken(true);
    } on FirebaseAuthException catch (error) {
      throw AccountDeletionFailure(
        AccountDeletionFailureCode.reauthRequired,
        switch (error.code) {
          'wrong-password' || 'invalid-credential' => 'Senha incorreta.',
          'too-many-requests' =>
            'Muitas tentativas. Aguarde um pouco e tente novamente.',
          'requires-recent-login' =>
            'Sua sessão expirou. Entre novamente para continuar.',
          _ => 'Não foi possível confirmar sua senha. Tente novamente.',
        },
      );
    }
  }

  @override
  Future<void> reauthenticateWithProvider() async {
    final user = _user;
    final provider = providerId;
    if (user == null) {
      throw const AccountDeletionFailure(
        AccountDeletionFailureCode.reauthRequired,
        'Entre novamente para confirmar sua conta.',
      );
    }
    try {
      await user.reauthenticateWithProvider(switch (provider) {
        'google.com' => GoogleAuthProvider(),
        'apple.com' => AppleAuthProvider(),
        _ => throw const AccountDeletionFailure(
          AccountDeletionFailureCode.unsupportedProvider,
          'Este tipo de login não permite confirmar a exclusão no app.',
        ),
      });
      await user.getIdToken(true);
    } on FirebaseAuthException catch (error) {
      throw AccountDeletionFailure(
        AccountDeletionFailureCode.reauthRequired,
        switch (error.code) {
          'too-many-requests' =>
            'Muitas tentativas. Aguarde um pouco e tente novamente.',
          'requires-recent-login' =>
            'Sua sessão expirou. Entre novamente para continuar.',
          _ => 'Não foi possível confirmar sua conta. Tente novamente.',
        },
      );
    }
  }

  @override
  Future<AccountDeletionResult> request(String requestId) async {
    try {
      final result = await _functions
          .httpsCallable('requestAccountDeletion')
          .call<dynamic>({'requestId': requestId});
      return accountDeletionResultFrom(result.data);
    } on FirebaseFunctionsException catch (error) {
      throw accountDeletionFailureFrom(
        code: error.code,
        details: error.details,
      );
    }
  }

  @override
  Future<void> clearLocalState() async {
    final uid = _user?.uid;
    if (uid == null) return;
    await clearAccountLocalState(_prefs, uid);
  }
}

/// Removes only the deleted parent's cached state. Other accounts on the same
/// device keep their scoped keys.
Future<void> clearAccountLocalState(SharedPreferences prefs, String uid) async {
  final prefixes = ['session.$uid.', 'lesson.pending.v1.$uid.'];
  for (final key in prefs.getKeys().toList()) {
    if (prefixes.any(key.startsWith)) {
      await prefs.remove(key);
    }
  }
  await prefs.remove('notifications.enabled.$uid');
  // The installation belongs to this device; a deleted family must not keep
  // receiving notifications under the old identity.
  await prefs.remove('notifications.installation');
  await prefs.remove('notifications.secret');
}

final accountDeletionServiceProvider = Provider<AccountDeletionService>((ref) {
  if (!AppConfig.useFirebase) return const UnsupportedAccountDeletionService();
  return FirebaseAccountDeletionService(
    ref.watch(firebaseAuthProvider),
    ref.watch(functionsProvider),
    ref.watch(sharedPreferencesProvider),
  );
});
