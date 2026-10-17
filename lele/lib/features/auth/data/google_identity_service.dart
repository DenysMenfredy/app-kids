import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/firebase_build_config.dart';
import '../domain/auth_failure.dart';

/// Only supplies Google's identity evidence. Firebase remains the account owner.
abstract interface class GoogleIdentityService {
  /// Null means the parent dismissed the account chooser.
  Future<String?> authenticate();
  Future<void> signOut();
}

class NativeGoogleIdentityService implements GoogleIdentityService {
  NativeGoogleIdentityService({
    GoogleSignIn? sdk,
    this._config = FirebaseBuildConfig.compiled,
    String? platform,
  }) : _sdk = sdk ?? GoogleSignIn.instance,
       _platform =
           platform ??
           (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');

  final GoogleSignIn _sdk;
  final FirebaseBuildConfig _config;
  final String _platform;
  Future<void>? _initialization;
  bool _initialized = false;

  Future<void> _initialize() async {
    _config.validateGoogleSignIn(platform: _platform);
    await _sdk.initialize(
      serverClientId: _config.value('GOOGLE_WEB_CLIENT_ID'),
      clientId: _platform == 'ios'
          ? _config.value('GOOGLE_IOS_CLIENT_ID')
          : null,
    );
    _initialized = true;
  }

  @override
  Future<String?> authenticate() async {
    try {
      await (_initialization ??= _initialize());
      // Clear only this app's Google session, never revoke the parent's grants.
      // A family device must not silently reuse the previous parent's account.
      await _sdk.signOut();
      final account = await _sdk.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const AuthFailure(
          'O Google não confirmou a identidade. Tente entrar novamente.',
        );
      }
      // Tokens are used once by Firebase; never log or persist them here.
      return token;
    } on FormatException {
      throw const AuthFailure(
        'O acesso com Google ainda não está configurado para este app.',
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw AuthFailure(googleIdentityErrorMessage(error.code));
    }
  }

  @override
  Future<void> signOut() async {
    if (!_initialized) return;
    try {
      await _sdk.signOut();
    } on GoogleSignInException catch (error) {
      throw AuthFailure(googleIdentityErrorMessage(error.code));
    }
  }
}

String googleIdentityErrorMessage(GoogleSignInExceptionCode code) =>
    switch (code) {
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        'O acesso com Google ainda não está configurado para este app.',
      GoogleSignInExceptionCode.interrupted =>
        'A entrada com Google foi interrompida. Tente novamente.',
      _ => 'Não foi possível entrar com Google agora. Tente novamente.',
    };
