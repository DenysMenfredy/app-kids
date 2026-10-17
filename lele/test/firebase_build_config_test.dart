import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/config/firebase_build_config.dart';

import '../tool/verify_firebase_config.dart' as build;

Map<String, String> fixture([String env = 'staging']) => {
  'USE_FIREBASE': 'true', 'APP_ENV': env,
  'FIREBASE_PROJECT_ID': 'letrando-$env',
  'FIREBASE_MESSAGING_SENDER_ID': '1234567890',
  'FIREBASE_STORAGE_BUCKET': 'letrando-$env.firebasestorage.app',
  'FIREBASE_ANDROID_PACKAGE_NAME': 'br.com.lele.lele',
  'FIREBASE_ANDROID_APP_ID': '1:1234567890:android:abcdef1234',
  // Syntactically valid test-only public metadata, not real credentials.
  'FIREBASE_ANDROID_API_KEY': 'AIza${'a' * 35}',
  'FIREBASE_IOS_BUNDLE_ID': 'br.com.lele.lele',
  'FIREBASE_IOS_APP_ID': '1:1234567890:ios:abcdef1234',
  'FIREBASE_IOS_API_KEY': 'AIza${'b' * 35}',
};

Map<String, dynamic> nativeFixture(Map<String, String> values) => {
  'project_info': {
    'project_id': values['FIREBASE_PROJECT_ID'],
    'project_number': values['FIREBASE_MESSAGING_SENDER_ID'],
    'storage_bucket': values['FIREBASE_STORAGE_BUCKET'],
  },
  'client': [
    {
      'client_info': {
        'mobilesdk_app_id': values['FIREBASE_ANDROID_APP_ID'],
        'android_client_info': {'package_name': FirebaseBuildConfig.nativeId},
      },
      'api_key': [
        {'current_key': values['FIREBASE_ANDROID_API_KEY']},
      ],
    },
  ],
};

void main() {
  test('debug demo and emulator remain reproducible without real config', () {
    const FirebaseBuildConfig({}).validate(platform: 'android', release: false);
    const FirebaseBuildConfig({
      'USE_FIREBASE': 'true',
      'USE_EMULATOR': 'true',
    }).validate(platform: 'android', release: false);
  });

  test('release never accepts fake auth, emulators or a dev project', () {
    for (final values in [
      <String, String>{},
      {'USE_FIREBASE': 'true', 'USE_EMULATOR': 'true'},
      fixture('dev'),
    ]) {
      expect(
        () => FirebaseBuildConfig(
          values,
        ).validate(platform: 'android', release: true),
        throwsFormatException,
      );
    }
  });

  test('explicit staging and production configure Android and iOS', () {
    for (final env in ['staging', 'production']) {
      for (final platform in ['android', 'ios']) {
        FirebaseBuildConfig(
          fixture(env),
        ).validate(platform: platform, release: true);
      }
    }
  });

  test('missing, wrong-project and wrong-platform options fail closed', () {
    for (final change in [
      {'APP_ENV': ''},
      {'APP_ENV': 'test'},
      {'FIREBASE_PROJECT_ID': 'letrando-dev'},
      {'FIREBASE_ANDROID_APP_ID': '1:1234567890:ios:abc'},
      {'FIREBASE_ANDROID_API_KEY': 'PLACEHOLDER'},
      {'FIREBASE_MESSAGING_SENDER_ID': 'invalid'},
      {'FIREBASE_STORAGE_BUCKET': 'another.appspot.com'},
      {'FIREBASE_ANDROID_PACKAGE_NAME': 'another.app'},
      {'EMULATOR_HOST': '10.0.2.2'},
    ]) {
      expect(
        () => FirebaseBuildConfig({
          ...fixture(),
          ...change,
        }).validate(platform: 'android', release: true),
        throwsFormatException,
      );
    }
    expect(
      () => const FirebaseBuildConfig({
        'USE_EMULATOR': 'true',
      }).validate(platform: 'android', release: false),
      throwsFormatException,
    );
    expect(
      () => const FirebaseBuildConfig({
        'USE_FIREBASE': 'yes',
      }).validate(platform: 'android', release: false),
      throwsFormatException,
    );
  });

  test('native config must match project, app, key and package together', () {
    final values = fixture();
    final config = FirebaseBuildConfig(values);
    build.verifyAndroidConfig(config, nativeFixture(values));
    for (final change in [
      {'FIREBASE_PROJECT_ID': 'letrando-production'},
      {'FIREBASE_MESSAGING_SENDER_ID': '9999999999'},
      {'FIREBASE_ANDROID_APP_ID': '1:1234567890:android:ffff'},
      {'FIREBASE_ANDROID_API_KEY': 'AIza${'z' * 35}'},
    ]) {
      expect(
        () => build.verifyAndroidConfig(
          config,
          nativeFixture({...values, ...change}),
        ),
        throwsFormatException,
      );
    }
  });

  test('Google OAuth uses this project audience and matching iOS scheme', () {
    final values = {
      ...fixture(),
      'GOOGLE_WEB_CLIENT_ID': '1234567890-web.apps.googleusercontent.com',
      'GOOGLE_IOS_CLIENT_ID': '1234567890-ios.apps.googleusercontent.com',
      'GOOGLE_IOS_REVERSED_CLIENT_ID':
          'com.googleusercontent.apps.1234567890-ios',
    };
    for (final platform in ['android', 'ios']) {
      FirebaseBuildConfig(values).validateGoogleSignIn(platform: platform);
    }
    for (final change in [
      {'GOOGLE_WEB_CLIENT_ID': ''},
      {'GOOGLE_WEB_CLIENT_ID': '999999-foreign.apps.googleusercontent.com'},
      {'GOOGLE_IOS_CLIENT_ID': ''},
      {'GOOGLE_IOS_REVERSED_CLIENT_ID': 'com.googleusercontent.apps.other'},
    ]) {
      expect(
        () => FirebaseBuildConfig({
          ...values,
          ...change,
        }).validateGoogleSignIn(platform: 'ios'),
        throwsFormatException,
      );
    }
  });

  test('native Android OAuth must match the selected web audience', () {
    final values = {
      ...fixture(),
      'GOOGLE_WEB_CLIENT_ID': '1234567890-web.apps.googleusercontent.com',
    };
    final native = nativeFixture(values);
    final client = (native['client'] as List).single as Map;
    client['oauth_client'] = [
      {'client_type': 3, 'client_id': values['GOOGLE_WEB_CLIENT_ID']},
    ];
    build.verifyAndroidConfig(FirebaseBuildConfig(values), native);
    client['oauth_client'] = [
      {
        'client_type': 3,
        'client_id': '1234567890-other.apps.googleusercontent.com',
      },
    ];
    expect(
      () => build.verifyAndroidConfig(FirebaseBuildConfig(values), native),
      throwsFormatException,
    );
    client['oauth_client'] = [];
    expect(
      () => build.verifyAndroidConfig(FirebaseBuildConfig(values), native),
      throwsFormatException,
    );
  });

  test('iOS native OAuth and Runner callback must both match the build', () {
    final values = {
      ...fixture(),
      'GOOGLE_WEB_CLIENT_ID': '1234567890-web.apps.googleusercontent.com',
      'GOOGLE_IOS_CLIENT_ID': '1234567890-ios.apps.googleusercontent.com',
      'GOOGLE_IOS_REVERSED_CLIENT_ID':
          'com.googleusercontent.apps.1234567890-ios',
    };
    final native = {
      'CLIENT_ID': values['GOOGLE_IOS_CLIENT_ID']!,
      'REVERSED_CLIENT_ID': values['GOOGLE_IOS_REVERSED_CLIENT_ID']!,
    };
    final config = FirebaseBuildConfig(values);
    build.verifyIosGoogleConfig(
      config,
      native,
      callbackSchemes: [native['REVERSED_CLIENT_ID']!],
    );
    for (final invalid in [
      {...native, 'CLIENT_ID': 'another.apps.googleusercontent.com'},
      {...native, 'REVERSED_CLIENT_ID': 'com.googleusercontent.apps.other'},
    ]) {
      expect(
        () => build.verifyIosGoogleConfig(
          config,
          invalid,
          callbackSchemes: [native['REVERSED_CLIENT_ID']!],
        ),
        throwsFormatException,
      );
    }
    expect(
      () => build.verifyIosGoogleConfig(
        config,
        native,
        callbackSchemes: const [],
      ),
      throwsFormatException,
    );
  });

  test('Flutter Base64 defines preserve equals signs and booleans', () {
    final encoded = [
      'USE_FIREBASE=true',
      'APP_ENV=staging',
      'KEY=abc==',
    ].map((value) => base64.encode(utf8.encode(value))).join(',');
    expect(build.decodeDartDefines(encoded), {
      'USE_FIREBASE': 'true',
      'APP_ENV': 'staging',
      'KEY': 'abc==',
    });
  });

  test('example is deliberately unshippable and carries no private keys', () {
    final values =
        (jsonDecode(File('config/firebase.example.json').readAsStringSync())
                as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, value.toString()));
    expect(
      () => FirebaseBuildConfig(
        values,
      ).validate(platform: 'android', release: true),
      throwsFormatException,
    );
    expect(
      values.keys.any(
        (key) => key.contains('PRIVATE') || key.contains('SECRET'),
      ),
      isFalse,
    );
  });
}
