import 'dart:convert';
import 'dart:io';

import 'package:lele/core/config/firebase_build_config.dart';

import 'verify_firebase_config.dart' show verifyAndroidConfig;

/// Reads only the flat string entries needed from Firebase's generated plist.
/// Rejects missing/encoded values; this is not a general-purpose plist parser.
Map<String, String> publicIosOptions(String xml) {
  final values = <String, String>{
    for (final key in [
      'PROJECT_ID',
      'GOOGLE_APP_ID',
      'API_KEY',
      'BUNDLE_ID',
      'GCM_SENDER_ID',
      'STORAGE_BUCKET',
    ])
      key: _plistString(xml, key),
  };
  for (final key in ['CLIENT_ID', 'REVERSED_CLIENT_ID']) {
    if (xml.contains('<key>$key</key>')) {
      values[key] = _plistString(xml, key);
    }
  }
  return values;
}

String _plistString(String xml, String key) {
  final matches = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<string>([^<&]*)</string>',
  ).allMatches(xml).toList();
  if (matches.length != 1 || matches.single.group(1)!.isEmpty) {
    throw FormatException(
      'Plist Firebase: campo $key ausente, duplicado ou não suportado.',
    );
  }
  return matches.single.group(1)!;
}

Map<String, String> generatePublicOptions(
  String environment,
  Map<String, dynamic> android, {
  Map<String, String>? ios,
}) {
  if (!FirebaseBuildConfig.projects.containsKey(environment)) {
    throw const FormatException('Use dev, staging ou production.');
  }
  final project = android['project_info'] as Map<String, dynamic>? ?? {};
  final clients = (android['client'] as List<dynamic>? ?? [])
      .whereType<Map<String, dynamic>>()
      .where((client) {
        final info = client['client_info'];
        final registration = info is Map ? info['android_client_info'] : null;
        return registration is Map &&
            registration['package_name'] == FirebaseBuildConfig.nativeId;
      })
      .toList();
  if (clients.length != 1) {
    throw const FormatException(
      'Selecione o app Android com package br.com.lele.lele; nenhum app será criado automaticamente.',
    );
  }
  final client = clients.single;
  final keys = (client['api_key'] as List<dynamic>? ?? [])
      .whereType<Map<String, dynamic>>();
  if (keys.length != 1) {
    throw const FormatException(
      'Configuração Android deve ter exatamente uma API key pública.',
    );
  }
  final result = <String, String>{
    'USE_FIREBASE': 'true',
    'USE_EMULATOR': 'false',
    'APP_ENV': environment,
    'FIREBASE_PROJECT_ID': project['project_id']?.toString() ?? '',
    'FIREBASE_MESSAGING_SENDER_ID': project['project_number']?.toString() ?? '',
    'FIREBASE_STORAGE_BUCKET': project['storage_bucket']?.toString() ?? '',
    'FIREBASE_ANDROID_PACKAGE_NAME': FirebaseBuildConfig.nativeId,
    'FIREBASE_ANDROID_APP_ID':
        (client['client_info'] as Map?)?['mobilesdk_app_id']?.toString() ?? '',
    'FIREBASE_ANDROID_API_KEY': keys.single['current_key']?.toString() ?? '',
  };
  final webClients = (client['oauth_client'] as List<dynamic>? ?? [])
      .whereType<Map<String, dynamic>>()
      .where((oauth) => oauth['client_type'] == 3)
      .map((oauth) => oauth['client_id']?.toString() ?? '')
      .toSet();
  if (webClients.length > 1) {
    throw const FormatException('Configuração OAuth Google ambígua.');
  }
  if (webClients.isNotEmpty) {
    result['GOOGLE_WEB_CLIENT_ID'] = webClients.single;
  }
  if (ios != null) {
    if (ios['PROJECT_ID'] != result['FIREBASE_PROJECT_ID'] ||
        ios['GCM_SENDER_ID'] != result['FIREBASE_MESSAGING_SENDER_ID'] ||
        ios['STORAGE_BUCKET'] != result['FIREBASE_STORAGE_BUCKET']) {
      throw const FormatException(
        'Os arquivos Android/iOS pertencem a projetos diferentes.',
      );
    }
    result.addAll({
      'FIREBASE_IOS_APP_ID': ios['GOOGLE_APP_ID'] ?? '',
      'FIREBASE_IOS_API_KEY': ios['API_KEY'] ?? '',
      'FIREBASE_IOS_BUNDLE_ID': ios['BUNDLE_ID'] ?? '',
    });
    if (ios.containsKey('CLIENT_ID') || ios.containsKey('REVERSED_CLIENT_ID')) {
      result.addAll({
        'GOOGLE_IOS_CLIENT_ID': ios['CLIENT_ID'] ?? '',
        'GOOGLE_IOS_REVERSED_CLIENT_ID': ios['REVERSED_CLIENT_ID'] ?? '',
      });
    }
  }
  final config = FirebaseBuildConfig(result);
  config.validate(platform: 'android', release: false);
  verifyAndroidConfig(config, android);
  if (ios != null) config.validate(platform: 'ios', release: false);
  if (webClients.isNotEmpty) {
    config.validateGoogleSignIn(platform: 'android');
  }
  if (result.containsKey('GOOGLE_IOS_CLIENT_ID')) {
    config.validateGoogleSignIn(platform: 'ios');
  }
  return result;
}

void main(List<String> args) {
  String? option(String name) => args
      .where((arg) => arg.startsWith('$name='))
      .map((arg) => arg.substring(name.length + 1))
      .firstOrNull;
  try {
    final env = option('--environment') ?? '';
    final androidPath = option('--android');
    final iosPath = option('--ios');
    if (androidPath == null || !File(androidPath).existsSync()) {
      throw const FormatException(
        'Baixe google-services.json do projeto escolhido e use --android=arquivo. Consulte config/README.md.',
      );
    }
    final options = generatePublicOptions(
      env,
      jsonDecode(File(androidPath).readAsStringSync()) as Map<String, dynamic>,
      ios: iosPath == null
          ? null
          : publicIosOptions(File(iosPath).readAsStringSync()),
    );
    final output = File('config/firebase.$env.json');
    // No overwrite switch: protect a configuration already reviewed by its owner.
    output.createSync(exclusive: true);
    output.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(options)}\n',
    );
    stdout.writeln(
      'Gerado ${output.path}; valores públicos não foram impressos. Nenhum projeto/app remoto foi criado ou alterado.',
    );
    if (iosPath == null) {
      stdout.writeln(
        'iOS ainda não configurado: forneça também o plist gerado para este projeto.',
      );
    }
  } on Object catch (error) {
    stderr.writeln(
      error is FormatException
          ? error.message
          : 'Não foi possível gerar o arquivo. Verifique os arquivos baixados e se config/firebase.<ambiente>.json já existe; nada é sobrescrito.',
    );
    exitCode = 1;
  }
}
