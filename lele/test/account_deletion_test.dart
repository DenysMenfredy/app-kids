import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/theme/app_theme.dart';
import 'package:lele/features/settings/data/account_deletion_service.dart';
import 'package:lele/features/settings/domain/account_deletion.dart';
import 'package:lele/features/settings/presentation/account_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDeletionService implements AccountDeletionService {
  AccountDeletionResult requestResult = const AccountDeletionResult(
    status: AccountDeletionStatus.requested,
    requestId: 'request-1',
    changed: true,
  );
  AccountDeletionFailure? requestFailure;
  int reauths = 0;
  int requests = 0;
  int cleans = 0;

  @override
  bool get supported => true;
  @override
  bool get isPasswordProvider => true;
  @override
  String? get email => 'synthetic@example.com';
  @override
  String? get providerId => 'password';

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    reauths++;
  }

  @override
  Future<void> reauthenticateWithProvider() async {
    reauths++;
  }

  @override
  Future<AccountDeletionResult> request(String requestId) async {
    requests++;
    if (requestFailure != null) throw requestFailure!;
    return requestResult;
  }

  @override
  Future<void> clearLocalState() async {
    cleans++;
  }
}

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(540, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('typed consent failures map to the app codes', () {
    expect(
      accountDeletionFailureFrom(
        code: 'failed-precondition',
        details: {'code': 'reauth_required'},
      ).code,
      AccountDeletionFailureCode.reauthRequired,
    );
    expect(
      accountDeletionFailureFrom(
        code: 'internal',
        details: {'code': 'session_revocation_failed'},
      ).code,
      AccountDeletionFailureCode.sessionRevocationFailed,
    );
    expect(
      accountDeletionFailureFrom(
        code: 'failed-precondition',
        details: {'code': 'account_deletion_pending'},
      ).code,
      AccountDeletionFailureCode.pending,
    );
  });

  test('request ids and results stay bounded', () {
    expect(
      RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(newAccountDeletionRequestId()),
      isTrue,
    );
    final result = accountDeletionResultFrom({
      'status': 'requested',
      'requestId': 'abc',
      'changed': true,
    });
    expect(result.status, AccountDeletionStatus.requested);
    expect(result.changed, isTrue);
    expect(
      () => accountDeletionResultFrom({'status': 'unknown'}),
      throwsA(isA<AccountDeletionFailure>()),
    );
  });

  test('local cleanup removes only the deleted parent keys', () async {
    SharedPreferences.setMockInitialValues({
      'session.uid-a.childName': 'Lia',
      'session.uid-b.childName': 'Caio',
      'lesson.pending.v1.uid-a.child-a': '{}',
      'lesson.pending.v1.uid-b.child-b': '{}',
      'notifications.enabled.uid-a': true,
      'notifications.enabled.uid-b': true,
      'notifications.installation': 'installation',
      'notifications.secret': 'secret',
    });
    final prefs = await SharedPreferences.getInstance();

    await clearAccountLocalState(prefs, 'uid-a');

    expect(prefs.getString('session.uid-a.childName'), isNull);
    expect(prefs.getString('session.uid-b.childName'), 'Caio');
    expect(prefs.getString('lesson.pending.v1.uid-a.child-a'), isNull);
    expect(prefs.getString('lesson.pending.v1.uid-b.child-b'), '{}');
    expect(prefs.getBool('notifications.enabled.uid-a'), isNull);
    expect(prefs.getBool('notifications.enabled.uid-b'), isTrue);
    expect(prefs.getString('notifications.installation'), isNull);
    expect(prefs.getString('notifications.secret'), isNull);
  });

  testWidgets('password reauthentication requests deletion and signs out', (
    tester,
  ) async {
    _useTallView(tester);
    final service = _FakeDeletionService();
    var signedOut = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [accountDeletionServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: AccountSettingsScreen(
            signOutOverride: () async => signedOut = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('não cancela'), findsOneWidget);
    expect(find.text('Gerenciar assinaturas na Google Play'), findsOneWidget);

    await tester.tap(find.text('Excluir minha conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Confirme sua identidade para continuar'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Senha12345');
    await tester.tap(find.text('Confirmar e excluir'));
    await tester.pumpAndSettle();

    expect(service.reauths, 1);
    expect(service.requests, 1);
    expect(find.text('Conta em exclusão'), findsOneWidget);

    await tester.tap(find.text('Sair da conta'));
    await tester.pumpAndSettle();
    expect(service.cleans, 1);
    expect(signedOut, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reauth_required keeps the password step and does not sign out', (
    tester,
  ) async {
    _useTallView(tester);
    final service = _FakeDeletionService()
      ..requestFailure = const AccountDeletionFailure(
        AccountDeletionFailureCode.reauthRequired,
        'Confirme sua senha ou entre novamente com o Google antes de excluir a conta.',
      );
    var signedOut = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [accountDeletionServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: AccountSettingsScreen(
            signOutOverride: () async => signedOut = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Excluir minha conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Senha12345');
    await tester.tap(find.text('Confirmar e excluir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Confirme sua senha'), findsOneWidget);
    expect(find.text('Conta em exclusão'), findsNothing);
    expect(service.cleans, 0);
    expect(signedOut, isFalse);
  });

  testWidgets('session revocation failure offers a retry and sign out', (
    tester,
  ) async {
    _useTallView(tester);
    final service = _FakeDeletionService()
      ..requestFailure = const AccountDeletionFailure(
        AccountDeletionFailureCode.sessionRevocationFailed,
        'A solicitação foi registrada, mas não foi possível encerrar todas as sessões. Tente novamente.',
      );
    var signedOut = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [accountDeletionServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: AccountSettingsScreen(
            signOutOverride: () async => signedOut = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Excluir minha conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Senha12345');
    await tester.tap(find.text('Confirmar e excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Solicitação registrada'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    service.requestFailure = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(service.requests, 2);
    expect(find.text('Conta em exclusão'), findsOneWidget);

    await tester.tap(find.text('Sair da conta'));
    await tester.pumpAndSettle();
    expect(service.cleans, 1);
    expect(signedOut, isTrue);
  });
}
