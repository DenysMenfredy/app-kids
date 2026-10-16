import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/features/notifications/application/notification_controller.dart';
import 'package:lele/features/notifications/domain/notification_ports.dart';
import 'package:lele/features/notifications/domain/notification_preferences.dart';
import 'package:lele/features/notifications/presentation/notification_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePlatform implements NotificationPlatform {
  bool permission = false;
  int demos = 0;
  int tokens = 0;
  int stops = 0;
  int clears = 0;
  Completer<String?>? pendingToken;
  @override
  bool get supported => true;
  @override
  String get platform => 'android';
  @override
  Future<void> initialize({
    required void Function() onOpen,
    required void Function() onTokenRefresh,
  }) async {}
  @override
  Future<bool> allowed() async => permission;
  @override
  Future<bool> requestPermission() async => permission;
  @override
  Future<void> showDemo() async {
    demos++;
  }

  @override
  Future<String?> token() async {
    tokens++;
    return pendingToken?.future ?? Future.value('test-token');
  }

  @override
  Future<void> stopRemote() async {
    stops++;
  }

  @override
  Future<void> clear() async {
    clears++;
  }

  @override
  void dispose() {}
}

class FakeRepository implements NotificationRepository {
  final registrations = <(String, Map<String, dynamic>)>[];
  final unregistrations = <String>[];
  bool failUnregister = false;
  NotificationPreferences stored = const NotificationPreferences();
  @override
  Future<NotificationPreferences> load(String uid) async => stored;
  @override
  Future<void> save(String uid, NotificationPreferences preferences) async {
    stored = preferences;
  }

  @override
  Future<void> register(String uid, Map<String, dynamic> installation) async {
    registrations.add((uid, installation));
  }

  @override
  Future<void> unregister(String uid, Map<String, dynamic> installation) async {
    unregistrations.add(uid);
    if (failUnregister) throw StateError('offline');
  }
}

void main() {
  late FakePlatform platform;
  late FakeRepository repository;
  late SharedPreferences prefs;
  late NotificationController controller;
  String? uid;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    platform = FakePlatform();
    repository = FakeRepository();
    uid = 'parent-a';
    controller = NotificationController(
      platform: platform,
      repository: repository,
      prefs: prefs,
      currentUid: () => uid,
      remoteEnabled: true,
    );
  });
  tearDown(() => controller.dispose());

  test('refusal is non-blocking and never creates a token', () async {
    await controller.enable();
    await controller.showDemo();
    expect(controller.permitted, isFalse);
    expect(controller.enabled, isFalse);
    expect(platform.tokens, 0);
    expect(platform.demos, 0);
    expect(controller.message, contains('continua disponível'));
  });

  test(
    'demo mode shows a native demo without requesting an FCM token',
    () async {
      final demo = NotificationController(
        platform: platform,
        prefs: prefs,
        currentUid: () => null,
        remoteEnabled: false,
      );
      addTearDown(demo.dispose);
      platform.permission = true;
      await demo.enable();
      await demo.showDemo();
      expect(platform.demos, 1);
      expect(platform.tokens, 0);
      expect(demo.message, contains('Não é um envio remoto'));
    },
  );

  test('installation survives retries and opt-in is parent scoped', () async {
    platform.permission = true;
    await controller.enable();
    await controller.refresh();
    final first = repository.registrations.first.$2;
    expect(first['deviceId'], matches(RegExp(r'^[a-f0-9]{32}$')));
    expect(first['installationSecret'], matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(repository.registrations.last.$2, first);
    uid = 'parent-b';
    await controller.refresh();
    expect(controller.enabled, isFalse);
    expect(repository.registrations, hasLength(2));
  });

  test('late token response cannot register for a previous parent', () async {
    platform.permission = true;
    platform.pendingToken = Completer<String?>();
    final enabling = controller.enable();
    while (platform.tokens == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    uid = 'parent-b';
    platform.pendingToken!.complete('late-token');
    await enabling;
    expect(repository.registrations, isEmpty);
    expect(controller.registered, isFalse);
  });

  test(
    'logout still invalidates token and clears tray if unregister is offline',
    () async {
      platform.permission = true;
      await controller.enable();
      repository.failUnregister = true;
      await controller.detachForSignOut();
      expect(platform.stops, 1);
      expect(platform.clears, 1);
      expect(controller.registered, isFalse);
    },
  );

  test(
    'category/time preferences persist independently of OS permission',
    () async {
      await controller.save(
        const NotificationPreferences(
          dailyReminder: false,
          preferredTime: '19:30',
          timezone: 'America/Belem',
        ),
      );
      expect(repository.stored.dailyReminder, isFalse);
      expect(repository.stored.preferredTime, '19:30');
      expect(repository.stored.toMap()['marketing'], isFalse);
      expect(platform.tokens, 0);
    },
  );

  testWidgets('parent screen labels local demo and shows refusal guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationControllerProvider.overrideWithValue(controller),
        ],
        child: const MaterialApp(home: NotificationSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Não testa o envio remoto'), findsOneWidget);
    await tester.tap(find.text('Ativar avisos neste aparelho'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(controller.message, contains('Você pode continuar usando o app'));
    await tester.scrollUntilVisible(
      find.textContaining('Você pode continuar usando o app'),
      200,
    );
    expect(
      find.textContaining('Você pode continuar usando o app'),
      findsOneWidget,
    );
    expect(platform.tokens, 0);
  });
}
