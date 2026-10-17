/// Public Firebase build metadata. No service credentials belong in this map.
/// Shared by startup and the build validator so they enforce the same boundary.
class FirebaseBuildConfig {
  const FirebaseBuildConfig(this.values);
  final Map<String, String> values;

  static const compiled = FirebaseBuildConfig({
    'USE_FIREBASE': String.fromEnvironment('USE_FIREBASE'),
    'USE_EMULATOR': String.fromEnvironment('USE_EMULATOR'),
    'EMULATOR_HOST': String.fromEnvironment('EMULATOR_HOST'),
    'APP_ENV': String.fromEnvironment('APP_ENV'),
    'FIREBASE_PROJECT_ID': String.fromEnvironment('FIREBASE_PROJECT_ID'),
    'FIREBASE_MESSAGING_SENDER_ID': String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    ),
    'FIREBASE_STORAGE_BUCKET': String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
    ),
    'FIREBASE_ANDROID_APP_ID': String.fromEnvironment(
      'FIREBASE_ANDROID_APP_ID',
    ),
    'FIREBASE_ANDROID_API_KEY': String.fromEnvironment(
      'FIREBASE_ANDROID_API_KEY',
    ),
    'FIREBASE_ANDROID_PACKAGE_NAME': String.fromEnvironment(
      'FIREBASE_ANDROID_PACKAGE_NAME',
    ),
    'FIREBASE_IOS_APP_ID': String.fromEnvironment('FIREBASE_IOS_APP_ID'),
    'FIREBASE_IOS_API_KEY': String.fromEnvironment('FIREBASE_IOS_API_KEY'),
    'FIREBASE_IOS_BUNDLE_ID': String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
    'GOOGLE_WEB_CLIENT_ID': String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
    'GOOGLE_IOS_CLIENT_ID': String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
    'GOOGLE_IOS_REVERSED_CLIENT_ID': String.fromEnvironment(
      'GOOGLE_IOS_REVERSED_CLIENT_ID',
    ),
    'FIREBASE_WEB_APP_ID': String.fromEnvironment('FIREBASE_WEB_APP_ID'),
    'FIREBASE_WEB_API_KEY': String.fromEnvironment('FIREBASE_WEB_API_KEY'),
    'FIREBASE_AUTH_DOMAIN': String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    'APP_CHECK_RECAPTCHA_SITE_KEY': String.fromEnvironment(
      'APP_CHECK_RECAPTCHA_SITE_KEY',
    ),
  });

  static const projects = {
    'dev': 'letrando-dev',
    'staging': 'letrando-staging',
    'production': 'letrando-production',
  };
  static const nativeId = 'br.com.lele.lele';
  String get environment => values['APP_ENV'] ?? '';
  String get projectId => values['FIREBASE_PROJECT_ID'] ?? '';
  bool get useFirebase => values['USE_FIREBASE'] == 'true';
  bool get useEmulator => values['USE_EMULATOR'] == 'true';
  String value(String key) => values[key] ?? '';

  /// Checked on a Google sign-in tap, so email auth can work before OAuth setup.
  void validateGoogleSignIn({required String platform}) {
    validate(platform: platform, release: false);
    if (!['android', 'ios'].contains(platform)) {
      throw const FormatException('Google nativo exige Android ou iOS.');
    }
    final sender = value('FIREBASE_MESSAGING_SENDER_ID');
    final pattern = RegExp(
      '^${RegExp.escape(sender)}-[a-zA-Z0-9_-]+\\.apps\\.googleusercontent\\.com\$',
    );
    if (sender.isEmpty || !pattern.hasMatch(value('GOOGLE_WEB_CLIENT_ID'))) {
      throw const FormatException(
        'Configure Google no Firebase e baixe novamente os arquivos públicos deste ambiente.',
      );
    }
    if (platform == 'ios') {
      final client = value('GOOGLE_IOS_CLIENT_ID');
      final expectedReverse =
          'com.googleusercontent.apps.${client.split('.apps.googleusercontent.com').first}';
      if (!pattern.hasMatch(client) ||
          value('GOOGLE_IOS_REVERSED_CLIENT_ID') != expectedReverse) {
        throw const FormatException(
          'Configure o cliente OAuth iOS e seu URL scheme neste ambiente.',
        );
      }
    }
  }

  void validate({required String platform, required bool release}) {
    if (!['android', 'ios', 'web'].contains(platform)) {
      throw const FormatException('Plataforma Firebase não suportada.');
    }
    for (final flag in ['USE_FIREBASE', 'USE_EMULATOR']) {
      if (!['', 'true', 'false'].contains(value(flag))) {
        throw FormatException('$flag deve ser true ou false.');
      }
    }
    if (useEmulator && !useFirebase) {
      throw const FormatException('USE_EMULATOR exige USE_FIREBASE=true.');
    }
    if (release && (!useFirebase || useEmulator)) {
      throw const FormatException(
        'Release exige Firebase real; demonstração e emuladores são proibidos.',
      );
    }
    if (!useFirebase || useEmulator) return;
    if (!projects.containsKey(environment)) {
      throw const FormatException(
        'Informe APP_ENV=dev, staging ou production e a configuração pública desse ambiente.',
      );
    }
    if (release && environment == 'dev') {
      throw const FormatException('Release não pode usar o ambiente dev.');
    }
    if (projectId != projects[environment]) {
      throw const FormatException(
        'FIREBASE_PROJECT_ID não corresponde a APP_ENV.',
      );
    }
    if (value('EMULATOR_HOST').isNotEmpty) {
      throw const FormatException(
        'EMULATOR_HOST só pode ser usado com USE_EMULATOR=true.',
      );
    }
    final sender = value('FIREBASE_MESSAGING_SENDER_ID');
    if (!RegExp(r'^[0-9]{6,20}$').hasMatch(sender)) {
      throw const FormatException(
        'FIREBASE_MESSAGING_SENDER_ID ausente ou inválido.',
      );
    }
    final prefix = 'FIREBASE_${platform.toUpperCase()}';
    if (!RegExp(
      '^1:$sender:$platform:[a-zA-Z0-9]+\$',
    ).hasMatch(value('${prefix}_APP_ID'))) {
      throw FormatException(
        '${prefix}_APP_ID ausente ou incompatível com plataforma/projeto.',
      );
    }
    if (!RegExp(
      r'^AIza[A-Za-z0-9_-]{35}$',
    ).hasMatch(value('${prefix}_API_KEY'))) {
      throw FormatException(
        '${prefix}_API_KEY ausente ou inválida. Use a configuração pública gerada pelo Firebase.',
      );
    }
    final bucket = value('FIREBASE_STORAGE_BUCKET');
    if (bucket != '$projectId.appspot.com' &&
        bucket != '$projectId.firebasestorage.app') {
      throw const FormatException(
        'FIREBASE_STORAGE_BUCKET não corresponde ao projeto.',
      );
    }
    if (platform == 'android' &&
            value('FIREBASE_ANDROID_PACKAGE_NAME') != nativeId ||
        platform == 'ios' && value('FIREBASE_IOS_BUNDLE_ID') != nativeId) {
      throw const FormatException(
        'O identificador nativo não corresponde a este app.',
      );
    }
    if (platform == 'web' &&
        (value('FIREBASE_AUTH_DOMAIN') != '$projectId.firebaseapp.com' ||
            value('APP_CHECK_RECAPTCHA_SITE_KEY').isEmpty)) {
      throw const FormatException(
        'Firebase web exige auth domain do projeto e APP_CHECK_RECAPTCHA_SITE_KEY.',
      );
    }
  }
}
