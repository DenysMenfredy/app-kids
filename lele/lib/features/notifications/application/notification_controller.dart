import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/storage/local_storage.dart';
import '../data/mobile_notification_platform.dart';
import '../data/notification_repository.dart';
import '../domain/notification_ports.dart';
import '../domain/notification_preferences.dart';

final notificationControllerProvider = Provider<NotificationController>((ref) {
  const remote = AppConfig.useFirebase && !AppConfig.useEmulator;
  final controller = NotificationController(
    platform: MobileNotificationPlatform(remoteEnabled: remote),
    prefs: ref.read(sharedPreferencesProvider),
    currentUid: () => AppConfig.useFirebase
        ? ref.read(firebaseAuthProvider).currentUser?.uid
        : null,
    repository: AppConfig.useFirebase
        ? FirebaseNotificationRepository(
            ref.read(firebaseAuthProvider),
            ref.read(firestoreProvider),
            ref.read(functionsProvider),
          )
        : null,
    remoteEnabled: remote,
  );
  if (AppConfig.useFirebase) {
    final subscription = ref
        .read(firebaseAuthProvider)
        .authStateChanges()
        .listen((_) => controller.refresh());
    ref.onDispose(() => unawaited(subscription.cancel()));
  }
  ref.onDispose(controller.dispose);
  return controller;
});

class NotificationController extends ChangeNotifier {
  NotificationController({
    required this.platform,
    required this.prefs,
    required this.currentUid,
    required this.remoteEnabled,
    this.repository,
  });

  final NotificationPlatform platform;
  final NotificationRepository? repository;
  final SharedPreferences prefs;
  final String? Function() currentUid;
  final bool remoteEnabled;
  NotificationPreferences preferences = const NotificationPreferences();
  bool busy = false;
  bool permitted = false;
  bool registered = false;
  String? message;
  bool _disposed = false;
  String? _loadedUid;
  Future<void> _queue = Future.value();
  void Function()? onOpen;

  String get _enabledKey => 'notifications.enabled.${currentUid() ?? 'demo'}';
  bool get enabled => prefs.getBool(_enabledKey) ?? false;
  bool get supported => platform.supported;
  bool get localDemo => !remoteEnabled;

  Future<void> _run(Future<void> Function() operation) {
    final next = _queue.then((_) async {
      if (_disposed) return;
      busy = true;
      message = null;
      notifyListeners();
      try {
        await operation();
      } catch (_) {
        message =
            'Não foi possível atualizar os avisos. Verifique a conexão e tente novamente.';
      } finally {
        busy = false;
        if (!_disposed) notifyListeners();
      }
    });
    _queue = next;
    return next;
  }

  Future<void> _initialize() => platform.initialize(
    onOpen: () => onOpen?.call(),
    onTokenRefresh: () => unawaited(refresh()),
  );

  Future<void> refresh() => _run(() async {
    await _initialize();
    permitted = await platform.allowed();
    final uid = currentUid();
    if (uid != _loadedUid) {
      preferences = const NotificationPreferences();
      registered = false;
    }
    _loadedUid = uid;
    if (uid != null && repository != null) {
      final loaded = await repository!.load(uid);
      if (currentUid() != uid) return;
      preferences = loaded;
    }
    await _register();
  });

  Map<String, dynamic> _installation() {
    String randomHex(int length) => List.generate(
      length,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final id = prefs.getString('notifications.installation') ?? randomHex(16);
    final secret = prefs.getString('notifications.secret') ?? randomHex(32);
    // Persist before any network request; survives retries and account switches.
    return {'deviceId': id, 'installationSecret': secret};
  }

  Future<Map<String, dynamic>> _savedInstallation() async {
    final installation = _installation();
    await prefs.setString(
      'notifications.installation',
      installation['deviceId'] as String,
    );
    await prefs.setString(
      'notifications.secret',
      installation['installationSecret'] as String,
    );
    return installation;
  }

  Future<void> _register() async {
    registered = false;
    final uid = currentUid();
    if (!remoteEnabled || uid == null || !enabled || !permitted) return;
    final installation = await _savedInstallation();
    final token = await platform.token();
    if (currentUid() != uid || token == null) return;
    await repository!.register(uid, {
      ...installation,
      'fcmToken': token,
      'platform': platform.platform,
      'permission': 'authorized',
      'notificationsEnabled': true,
    });
    registered = currentUid() == uid;
  }

  Future<void> enable() => _run(() async {
    await _initialize();
    permitted = await platform.requestPermission();
    await prefs.setBool(_enabledKey, permitted);
    if (!permitted) {
      message =
          'Permissão não concedida. Você pode continuar usando o app e ativar os avisos nos ajustes do aparelho.';
      return;
    }
    await _register();
    message = localDemo
        ? 'Avisos permitidos. A demonstração é local neste ambiente.'
        : registered
        ? 'Este aparelho está conectado aos avisos.'
        : 'Entre na conta para conectar os avisos.';
  });

  Future<void> showDemo() => _run(() async {
    await _initialize();
    permitted = await platform.allowed();
    if (!permitted) {
      message =
          'Ative a permissão acima para ver a demonstração. O app continua disponível sem ela.';
      return;
    }
    await platform.showDemo();
    message =
        'Demonstração enviada ao sistema. Abra a central de notificações para ver. Não é um envio remoto do Firebase.';
  });

  Future<void> save(NotificationPreferences next) => _run(() async {
    final uid = currentUid();
    if (repository != null && uid != null) {
      await repository!.save(uid, next);
      if (currentUid() != uid) return;
    } else {
      message =
          'Preferências de exemplo; entre em uma conta para salvar no servidor.';
    }
    preferences = next;
  });

  Future<void> disable() => _run(() async {
    await prefs.setBool(_enabledKey, false);
    await _detach();
    message = 'Avisos desativados neste aparelho.';
  });

  Future<void> detachForSignOut() => _run(_detach);

  Future<void> _detach() async {
    registered = false;
    final uid = currentUid();
    try {
      if (remoteEnabled &&
          uid != null &&
          prefs.containsKey('notifications.installation')) {
        await repository!
            .unregister(uid, _installation())
            .timeout(const Duration(seconds: 5));
      }
    } finally {
      try {
        await platform.stopRemote().timeout(const Duration(seconds: 5));
      } finally {
        await platform.clear();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    platform.dispose();
    super.dispose();
  }
}
