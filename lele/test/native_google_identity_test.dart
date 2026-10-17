import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lele/core/config/firebase_build_config.dart';
import 'package:lele/features/auth/data/firebase_auth_repository.dart';
import 'package:lele/features/auth/data/google_identity_service.dart';
import 'package:lele/features/auth/domain/auth_failure.dart';
import 'package:lele/features/auth/domain/sign_in_outcome.dart';

import 'firebase_build_config_test.dart' show fixture;

Map<String, String> googleFixture() => {
  ...fixture(),
  'GOOGLE_WEB_CLIENT_ID': '1234567890-web.apps.googleusercontent.com',
  'GOOGLE_IOS_CLIENT_ID': '1234567890-ios.apps.googleusercontent.com',
  'GOOGLE_IOS_REVERSED_CLIENT_ID': 'com.googleusercontent.apps.1234567890-ios',
};

class _Account extends Fake implements GoogleSignInAccount {
  _Account(this.token);
  final String? token;
  @override
  GoogleSignInAuthentication get authentication =>
      GoogleSignInAuthentication(idToken: token);
}

class _Google extends Fake implements GoogleSignIn {
  String? token = 'test-only-id-token';
  Object? failure;
  String? clientId;
  String? serverClientId;
  int initializations = 0;
  final calls = <String>[];

  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? nonce,
    String? hostedDomain,
  }) async {
    initializations++;
    this.clientId = clientId;
    this.serverClientId = serverClientId;
  }

  @override
  Future<void> signOut() async => calls.add('signOut');

  @override
  Future<GoogleSignInAccount> authenticate({
    List<String> scopeHint = const [],
  }) async {
    calls.add('authenticate');
    expect(scopeHint, isEmpty, reason: 'no contacts/Drive scopes needed');
    if (failure != null) throw failure!;
    return _Account(token);
  }
}

class _Identity extends Fake implements GoogleIdentityService {
  String? token = 'test-only-id-token';
  Object? signOutFailure;
  @override
  Future<String?> authenticate() async => token;
  @override
  Future<void> signOut() async {
    if (signOutFailure != null) throw signOutFailure!;
  }
}

class _Info extends Fake implements AdditionalUserInfo {
  _Info(this.isNewUser);
  @override
  final bool isNewUser;
}

class _Credential extends Fake implements UserCredential {
  _Credential(bool isNew) : additionalUserInfo = _Info(isNew);
  @override
  final AdditionalUserInfo additionalUserInfo;
}

class _Auth extends Fake implements FirebaseAuth {
  bool isNew = true;
  bool signedOut = false;
  Object? failure;
  AuthCredential? received;
  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    received = credential;
    if (failure != null) throw failure!;
    return _Credential(isNew);
  }

  @override
  Future<void> signOut() async => signedOut = true;
}

void main() {
  group('native Google identity', () {
    test(
      'initializes once with web audience and always opens chooser',
      () async {
        final sdk = _Google();
        final identity = NativeGoogleIdentityService(
          sdk: sdk,
          config: FirebaseBuildConfig(googleFixture()),
          platform: 'android',
        );
        expect(await identity.authenticate(), sdk.token);
        expect(await identity.authenticate(), sdk.token);
        expect(sdk.initializations, 1);
        expect(sdk.clientId, isNull);
        expect(sdk.serverClientId, googleFixture()['GOOGLE_WEB_CLIENT_ID']);
        expect(sdk.calls, [
          'signOut',
          'authenticate',
          'signOut',
          'authenticate',
        ]);
      },
    );

    test('iOS also receives the iOS OAuth client ID', () async {
      final sdk = _Google();
      await NativeGoogleIdentityService(
        sdk: sdk,
        config: FirebaseBuildConfig(googleFixture()),
        platform: 'ios',
      ).authenticate();
      expect(sdk.clientId, googleFixture()['GOOGLE_IOS_CLIENT_ID']);
    });

    test('missing OAuth config fails before invoking native SDK', () async {
      final sdk = _Google();
      await expectLater(
        NativeGoogleIdentityService(
          sdk: sdk,
          config: FirebaseBuildConfig(fixture()),
        ).authenticate(),
        throwsA(isA<AuthFailure>()),
      );
      expect(sdk.initializations, 0);
      expect(sdk.calls, isEmpty);
    });

    test('dismissal is a quiet cancellation, not an account', () async {
      final sdk = _Google()
        ..failure = const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
        );
      expect(
        await NativeGoogleIdentityService(
          sdk: sdk,
          config: FirebaseBuildConfig(googleFixture()),
        ).authenticate(),
        isNull,
      );
    });

    test('configuration failures never expose SDK details', () async {
      final sdk = _Google()
        ..failure = const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
          description: 'sensitive SDK detail',
        );
      await expectLater(
        NativeGoogleIdentityService(
          sdk: sdk,
          config: FirebaseBuildConfig(googleFixture()),
        ).authenticate(),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.message,
            'safe message',
            'O acesso com Google ainda não está configurado para este app.',
          ),
        ),
      );
    });

    test('empty or missing ID tokens cannot reach Firebase', () async {
      for (final token in [null, '']) {
        await expectLater(
          NativeGoogleIdentityService(
            sdk: _Google()..token = token,
            config: FirebaseBuildConfig(googleFixture()),
          ).authenticate(),
          throwsA(isA<AuthFailure>()),
        );
      }
    });

    test('email-only logout does not initialize the Google SDK', () async {
      final sdk = _Google();
      await NativeGoogleIdentityService(sdk: sdk).signOut();
      expect(sdk.initializations, 0);
      expect(sdk.calls, isEmpty);
    });
  });

  group('Google evidence becomes a Firebase account', () {
    test('exchanges ID token; only Firebase decides new/returning', () async {
      final auth = _Auth();
      final identity = _Identity();
      final repository = FirebaseAuthRepository(auth, googleIdentity: identity);
      expect(await repository.signInWithGoogle(), SignInOutcome.created);
      final credential = auth.received! as OAuthCredential;
      expect(credential.providerId, 'google.com');
      expect(credential.idToken, identity.token);
      auth.isNew = false;
      expect(await repository.signInWithGoogle(), SignInOutcome.returning);
    });

    test('cancellation never calls Firebase sign-in', () async {
      final auth = _Auth();
      final repository = FirebaseAuthRepository(
        auth,
        googleIdentity: _Identity()..token = null,
      );
      expect(await repository.signInWithGoogle(), SignInOutcome.cancelled);
      expect(auth.received, isNull);
    });

    test(
      'Firebase collision is surfaced, never merged by client email',
      () async {
        final auth = _Auth()
          ..failure = FirebaseAuthException(
            code: 'account-exists-with-different-credential',
          );
        await expectLater(
          FirebaseAuthRepository(
            auth,
            googleIdentity: _Identity(),
          ).signInWithGoogle(),
          throwsA(isA<AuthFailure>()),
        );
        // _Auth has no account lookup/link methods: any attempted merge fails.
      },
    );

    test(
      'SDK cleanup failure cannot retain the Firebase family session',
      () async {
        final auth = _Auth();
        await expectLater(
          FirebaseAuthRepository(
            auth,
            googleIdentity: _Identity()
              ..signOutFailure = const AuthFailure('Test cleanup failure'),
          ).signOut(),
          throwsA(isA<AuthFailure>()),
        );
        expect(auth.signedOut, isTrue);
      },
    );
  });
}
