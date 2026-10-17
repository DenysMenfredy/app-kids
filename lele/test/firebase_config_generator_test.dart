import 'package:flutter_test/flutter_test.dart';

import '../tool/generate_firebase_config.dart';
import 'firebase_build_config_test.dart' show fixture, nativeFixture;

void main() {
  test('copies only real OAuth clients and rejects ambiguous audiences', () {
    final source = nativeFixture(fixture());
    final client = (source['client'] as List).single as Map;
    client['oauth_client'] = [
      {
        'client_type': 3,
        'client_id': '1234567890-web.apps.googleusercontent.com',
      },
    ];
    expect(
      generatePublicOptions('staging', source)['GOOGLE_WEB_CLIENT_ID'],
      '1234567890-web.apps.googleusercontent.com',
    );
    (client['oauth_client'] as List).add({
      'client_type': 3,
      'client_id': '1234567890-other.apps.googleusercontent.com',
    });
    expect(
      () => generatePublicOptions('staging', source),
      throwsFormatException,
    );
  });

  test(
    'derives public values only from the downloaded native registration',
    () {
      final source = fixture('dev');
      final generated = generatePublicOptions('dev', nativeFixture(source));
      expect(
        generated['FIREBASE_ANDROID_APP_ID'],
        source['FIREBASE_ANDROID_APP_ID'],
      );
      expect(
        generated['FIREBASE_ANDROID_API_KEY'],
        source['FIREBASE_ANDROID_API_KEY'],
      );
      expect(generated['APP_ENV'], 'dev');
      expect(generated.containsKey('FIREBASE_IOS_APP_ID'), isFalse);
    },
  );
  test('rejects wrong project rather than editing remote registrations', () {
    expect(
      () => generatePublicOptions('staging', nativeFixture(fixture('dev'))),
      throwsFormatException,
    );
  });
  test('combines Android and iOS only for the same project and native ID', () {
    final source = fixture();
    final ios = {
      'PROJECT_ID': source['FIREBASE_PROJECT_ID']!,
      'GCM_SENDER_ID': source['FIREBASE_MESSAGING_SENDER_ID']!,
      'STORAGE_BUCKET': source['FIREBASE_STORAGE_BUCKET']!,
      'GOOGLE_APP_ID': source['FIREBASE_IOS_APP_ID']!,
      'API_KEY': source['FIREBASE_IOS_API_KEY']!,
      'BUNDLE_ID': 'br.com.lele.lele',
    };
    expect(
      generatePublicOptions(
        'staging',
        nativeFixture(source),
        ios: ios,
      )['FIREBASE_IOS_APP_ID'],
      source['FIREBASE_IOS_APP_ID'],
    );
    expect(
      () => generatePublicOptions(
        'staging',
        nativeFixture(source),
        ios: {...ios, 'PROJECT_ID': 'letrando-production'},
      ),
      throwsFormatException,
    );
    expect(
      () => generatePublicOptions(
        'staging',
        nativeFixture(source),
        ios: {...ios, 'BUNDLE_ID': 'another.app'},
      ),
      throwsFormatException,
    );
  });
  test(
    'reads generated flat plist without accepting ambiguous or encoded entries',
    () {
      const values = {
        'PROJECT_ID': 'letrando-dev',
        'GOOGLE_APP_ID': 'test',
        'API_KEY': 'test',
        'BUNDLE_ID': 'br.com.lele.lele',
        'GCM_SENDER_ID': '1234567890',
        'STORAGE_BUCKET': 'letrando-dev.appspot.com',
      };
      final xml =
          '<plist><dict>${values.entries.map((entry) => '<key>${entry.key}</key><string>${entry.value}</string>').join()}</dict></plist>';
      expect(publicIosOptions(xml), values);
      expect(
        () => publicIosOptions('$xml<key>API_KEY</key><string>other</string>'),
        throwsFormatException,
      );
      expect(
        () => publicIosOptions(
          xml.replaceAll('<string>test</string>', '<string>&amp;</string>'),
        ),
        throwsFormatException,
      );
    },
  );

  test('reads optional iOS OAuth fields without inventing absent ones', () {
    final values = fixture();
    final ios = {
      'PROJECT_ID': values['FIREBASE_PROJECT_ID']!,
      'GCM_SENDER_ID': values['FIREBASE_MESSAGING_SENDER_ID']!,
      'STORAGE_BUCKET': values['FIREBASE_STORAGE_BUCKET']!,
      'GOOGLE_APP_ID': values['FIREBASE_IOS_APP_ID']!,
      'API_KEY': values['FIREBASE_IOS_API_KEY']!,
      'BUNDLE_ID': 'br.com.lele.lele',
      'CLIENT_ID': '1234567890-ios.apps.googleusercontent.com',
      'REVERSED_CLIENT_ID': 'com.googleusercontent.apps.1234567890-ios',
    };
    final xml =
        '<plist><dict>${ios.entries.map((e) => '<key>${e.key}</key><string>${e.value}</string>').join()}</dict></plist>';
    expect(publicIosOptions(xml), ios);
    final android = nativeFixture(values);
    ((android['client'] as List).single as Map)['oauth_client'] = [
      {
        'client_type': 3,
        'client_id': '1234567890-web.apps.googleusercontent.com',
      },
    ];
    final generated = generatePublicOptions('staging', android, ios: ios);
    expect(generated['GOOGLE_IOS_CLIENT_ID'], ios['CLIENT_ID']);
    expect(
      generated['GOOGLE_IOS_REVERSED_CLIENT_ID'],
      ios['REVERSED_CLIENT_ID'],
    );
    expect(
      () => generatePublicOptions(
        'staging',
        android,
        ios: {...ios}..remove('REVERSED_CLIENT_ID'),
      ),
      throwsFormatException,
    );
  });
}
