import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/notification_ports.dart';

class MobileNotificationPlatform implements NotificationPlatform {
  MobileNotificationPlatform({required this.remoteEnabled});
  final bool remoteEnabled;
  final _local = FlutterLocalNotificationsPlugin();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void>? _initializing;
  final Set<String> _seen = {};

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  @override
  String get platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'lele_parent_updates',
      'Avisos para os pais',
      channelDescription: 'Lembretes e avisos do Lelê, sem dados das crianças.',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
      visibility: NotificationVisibility.private,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );

  @override
  Future<void> initialize({
    required void Function() onOpen,
    required void Function() onTokenRefresh,
  }) => _initializing ??= _initialize(onOpen, onTokenRefresh);

  Future<void> _initialize(
    void Function() onOpen,
    void Function() onTokenRefresh,
  ) async {
    if (!supported) return;
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (_) => onOpen(),
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'lele_parent_updates',
            'Avisos para os pais',
            importance: Importance.high,
          ),
        );
    if ((await _local.getNotificationAppLaunchDetails())
            ?.didNotificationLaunchApp ==
        true) {
      onOpen();
    }
    if (!remoteEnabled) return;
    // Present foreground pushes ourselves; do not display twice on Apple.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions();
    _subscriptions.add(
      FirebaseMessaging.instance.onTokenRefresh.listen((_) => onTokenRefresh()),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen((_) => onOpen()),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessage.listen((message) {
        unawaited(_foreground(message).catchError((Object _) {}));
      }),
    );
    if (await FirebaseMessaging.instance.getInitialMessage() != null) onOpen();
  }

  Future<void> _foreground(RemoteMessage message) async {
    if (!await allowed()) return;
    final id = message.data['notificationId'] ?? message.messageId;
    if (id == null || !_seen.add(id)) return;
    if (_seen.length > 100) _seen.remove(_seen.first);
    // Only generic server-authored text; never interpolate child or profile data.
    await _local.show(
      id: id.hashCode & 0x7fffffff,
      title: message.notification?.title ?? 'Lelê',
      body: message.notification?.body ?? 'Há uma novidade no painel dos pais.',
      notificationDetails: _details,
      payload: 'parent-dashboard',
    );
  }

  @override
  Future<bool> allowed() async {
    if (!supported) return false;
    if (platform == 'android') {
      return await _local
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled() ??
          false;
    }
    return (await _local
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.checkPermissions())
            ?.isEnabled ??
        false;
  }

  @override
  Future<bool> requestPermission() async {
    if (!supported) return false;
    if (platform == 'android') {
      return await _local
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _local
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true, badge: false) ??
        false;
  }

  @override
  Future<void> showDemo() => _local.show(
    id: 71001,
    title: 'Lelê • Demonstração',
    body:
        'Um pouquinho por dia, uma grande descoberta! Abra o painel dos pais.',
    notificationDetails: _details,
    payload: 'parent-dashboard',
  );

  @override
  Future<String?> token() async {
    if (!remoteEnabled) return null;
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    if (platform == 'ios' &&
        await FirebaseMessaging.instance.getAPNSToken() == null) {
      throw StateError('APNs ainda não disponível.');
    }
    return FirebaseMessaging.instance.getToken();
  }

  @override
  Future<void> stopRemote() async {
    if (!remoteEnabled) return;
    await FirebaseMessaging.instance.setAutoInitEnabled(false);
    await FirebaseMessaging.instance.deleteToken();
  }

  @override
  Future<void> clear() async {
    if (supported) await _local.cancelAll();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
  }
}
