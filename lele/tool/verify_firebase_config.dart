import 'dart:convert';
import 'dart:io';

import 'package:lele/core/config/firebase_build_config.dart';

Map<String, String> decodeDartDefines(String encoded) => {
  for (final entry in encoded.split(',').where((entry) => entry.isNotEmpty))
    ..._entry(utf8.decode(base64.decode(base64.normalize(entry)))),
};

Map<String, String> _entry(String entry) {
  final index = entry.indexOf('=');
  if (index < 1) throw const FormatException('Dart define inválido.');
  return {entry.substring(0, index): entry.substring(index + 1)};
}

void verifyAndroidConfig(
  FirebaseBuildConfig config,
  Map<String, dynamic> native,
) {
  final info = native['project_info'] as Map<String, dynamic>?;
  if (info?['project_id'] != config.projectId ||
      info?['project_number']?.toString() !=
          config.value('FIREBASE_MESSAGING_SENDER_ID') ||
      info?['storage_bucket'] != config.value('FIREBASE_STORAGE_BUCKET')) {
    throw const FormatException(
      'google-services.json não corresponde ao projeto/ambiente selecionado.',
    );
  }
  final clients = (native['client'] as List<dynamic>? ?? [])
      .whereType<Map<String, dynamic>>();
  final matches = clients.where((client) {
    final clientInfo = client['client_info'] as Map<String, dynamic>?;
    final android = clientInfo?['android_client_info'] as Map<String, dynamic>?;
    return clientInfo?['mobilesdk_app_id'] ==
            config.value('FIREBASE_ANDROID_APP_ID') &&
        android?['package_name'] == FirebaseBuildConfig.nativeId &&
        (client['api_key'] as List<dynamic>? ?? []).any(
          (key) =>
              key is Map &&
              key['current_key'] == config.value('FIREBASE_ANDROID_API_KEY'),
        );
  });
  if (matches.length != 1) {
    throw const FormatException(
      'google-services.json não tem exatamente um app/key/package correspondente.',
    );
  }
  if (config.value('GOOGLE_WEB_CLIENT_ID').isNotEmpty) {
    config.validateGoogleSignIn(platform: 'android');
    final clients = (matches.single['oauth_client'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .where((client) => client['client_type'] == 3)
        .map((client) => client['client_id'])
        .toSet();
    if (clients.length != 1 ||
        clients.single != config.value('GOOGLE_WEB_CLIENT_ID')) {
      throw const FormatException(
        'O cliente OAuth web não corresponde ao google-services.json selecionado.',
      );
    }
  }
}

void verifyIosGoogleConfig(
  FirebaseBuildConfig config,
  Map<String, String> native, {
  required Iterable<String> callbackSchemes,
}) {
  config.validateGoogleSignIn(platform: 'ios');
  final reversed = config.value('GOOGLE_IOS_REVERSED_CLIENT_ID');
  if (native['CLIENT_ID'] != config.value('GOOGLE_IOS_CLIENT_ID') ||
      native['REVERSED_CLIENT_ID'] != reversed ||
      !callbackSchemes.contains(reversed)) {
    throw const FormatException(
      'O cliente Google iOS ou o URL scheme do Runner não corresponde ao ambiente selecionado.',
    );
  }
}

Future<void> main(List<String> args) async {
  String? option(String name) {
    for (final arg in args) {
      if (arg.startsWith('$name=')) return arg.substring(name.length + 1);
    }
    return null;
  }

  try {
    final file = option('--config');
    final encoded = option('--defines');
    if ((file == null) == (encoded == null)) {
      throw const FormatException(
        'Use --config=arquivo.json ou --defines=valor-do-Flutter.',
      );
    }
    if (file != null && !File(file).existsSync()) {
      throw const FormatException(
        'Configuração pública ausente. Gere config/firebase.<APP_ENV>.json com os registros Firebase reais; consulte config/README.md.',
      );
    }
    final values = file == null
        ? decodeDartDefines(encoded!)
        : (jsonDecode(await File(file).readAsString()) as Map<String, dynamic>)
              .map((key, value) => MapEntry(key, value.toString()));
    // Public build configuration must not become a vehicle for private keys.
    if (values.keys.any(
      (key) => RegExp(
        '(PRIVATE_KEY|SERVICE_ACCOUNT|CLIENT_SECRET|PASSWORD|STRIPE)',
        caseSensitive: false,
      ).hasMatch(key),
    )) {
      throw const FormatException(
        'Secrets/credenciais de serviço são proibidos na configuração do cliente.',
      );
    }
    final config = FirebaseBuildConfig(values);
    final platform = option('--platform') ?? 'android';
    config.validate(platform: platform, release: args.contains('--release'));
    final requiredEnvironment = option('--environment');
    if (requiredEnvironment != null &&
        config.environment != requiredEnvironment) {
      throw const FormatException(
        'APP_ENV não corresponde ao ambiente exigido pelo pipeline.',
      );
    }
    if (config.useFirebase && !config.useEmulator) {
      if (platform == 'android') {
        final path = option('--native') ?? 'android/app/google-services.json';
        if (!File(path).existsSync()) {
          throw const FormatException(
            'google-services.json ausente. Configure o registro Android deste ambiente.',
          );
        }
        verifyAndroidConfig(
          config,
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>,
        );
      } else if (platform == 'ios') {
        if (!Platform.isMacOS) {
          throw const FormatException(
            'Valide o registro iOS em um Mac com PlistBuddy/Xcode.',
          );
        }
        final path =
            option('--native') ?? 'ios/Runner/GoogleService-Info.plist';
        for (final entry in {
          'PROJECT_ID': config.projectId,
          'GOOGLE_APP_ID': config.value('FIREBASE_IOS_APP_ID'),
          'API_KEY': config.value('FIREBASE_IOS_API_KEY'),
          'BUNDLE_ID': FirebaseBuildConfig.nativeId,
          'GCM_SENDER_ID': config.value('FIREBASE_MESSAGING_SENDER_ID'),
          'STORAGE_BUCKET': config.value('FIREBASE_STORAGE_BUCKET'),
        }.entries) {
          final result = await Process.run('/usr/libexec/PlistBuddy', [
            '-c',
            'Print :${entry.key}',
            path,
          ]);
          if (result.exitCode != 0 ||
              result.stdout.toString().trim() != entry.value) {
            throw const FormatException(
              'GoogleService-Info.plist ausente ou incompatível com o ambiente.',
            );
          }
        }
        if (config.value('GOOGLE_IOS_CLIENT_ID').isNotEmpty ||
            config.value('GOOGLE_IOS_REVERSED_CLIENT_ID').isNotEmpty) {
          final oauth = <String, String>{};
          for (final key in ['CLIENT_ID', 'REVERSED_CLIENT_ID']) {
            final result = await Process.run('/usr/libexec/PlistBuddy', [
              '-c',
              'Print :$key',
              path,
            ]);
            oauth[key] = result.exitCode == 0
                ? result.stdout.toString().trim()
                : '';
          }
          final callbacks = await Process.run('/usr/libexec/PlistBuddy', [
            '-c',
            'Print :CFBundleURLTypes',
            option('--ios-info') ?? 'ios/Runner/Info.plist',
          ]);
          verifyIosGoogleConfig(
            config,
            oauth,
            callbackSchemes: callbacks.exitCode == 0
                ? callbacks.stdout.toString().split('\n').map((s) => s.trim())
                : const [],
          );
        }
      }
    }
    stdout.writeln(
      'Firebase config validada: ${config.useEmulator
          ? 'demo emulator'
          : config.useFirebase
          ? config.environment
          : 'local debug'} / $platform.',
    );
  } on Object catch (error) {
    stderr.writeln(
      error is FormatException
          ? 'Firebase build: ${error.message}'
          : 'Firebase build: não foi possível ler/validar a configuração pública.',
    );
    exitCode = 1;
  }
}
