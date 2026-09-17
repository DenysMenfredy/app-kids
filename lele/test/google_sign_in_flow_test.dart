import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lele/app/router/app_router.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/core/theme/app_theme.dart';
import 'package:lele/features/auth/data/auth_repository.dart';
import 'package:lele/features/auth/data/firebase_auth_repository.dart';
import 'package:lele/features/auth/domain/auth_failure.dart';
import 'package:lele/features/auth/domain/sign_in_outcome.dart';
import 'package:lele/features/auth/presentation/google_sign_in_button.dart';
import 'package:lele/features/auth/presentation/login_screen.dart';
import 'package:lele/features/auth/presentation/register_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An auth boundary that answers however the test needs it to.
class ScriptedAuth implements AuthRepository {
  ScriptedAuth({this.outcome = SignInOutcome.returning, this.failure});

  final SignInOutcome outcome;
  final AuthFailure? failure;
  int googleCalls = 0;

  @override
  Future<SignInOutcome> signInWithGoogle() async {
    googleCalls++;
    if (failure != null) throw failure!;
    return outcome;
  }

  @override
  Future<SignInOutcome> signInWithApple() async => outcome;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}

  @override
  String? get currentUserId => null;
}

/// The screens the flow can land on, stubbed so arrival is unambiguous.
GoRouter _router(Widget home) => GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', name: AppRoutes.login, builder: (_, _) => home),
    GoRoute(
      path: '/profile-setup',
      name: AppRoutes.profileSetup,
      builder: (_, _) => const Scaffold(body: Text('@profileSetup')),
    ),
    GoRoute(
      path: '/dashboard',
      name: AppRoutes.dashboard,
      builder: (_, _) => const Scaffold(body: Text('@dashboard')),
    ),
  ],
);

Future<ScriptedAuth> pumpLogin(
  WidgetTester tester, {
  SignInOutcome outcome = SignInOutcome.returning,
  AuthFailure? failure,
  Widget home = const LoginScreen(),
}) async {
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = ScriptedAuth(outcome: outcome, failure: failure);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(auth),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: _router(home),
      ),
    ),
  );
  await tester.pump();
  return auth;
}

Future<void> tapGoogle(WidgetTester tester) async {
  await tester.tap(find.byType(GoogleSignInButton));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  group('where a Google sign-in lands you', () {
    testWidgets('a brand-new account goes to onboarding, not the dashboard', (
      tester,
    ) async {
      await pumpLogin(tester, outcome: SignInOutcome.created);
      await tapGoogle(tester);

      expect(
        find.text('@profileSetup'),
        findsOneWidget,
        reason:
            'a new parent has no child yet — the dashboard would be '
            'a summary of a family that does not exist',
      );
      expect(find.text('@dashboard'), findsNothing);
    });

    testWidgets('a returning account goes straight to the dashboard', (
      tester,
    ) async {
      await pumpLogin(tester, outcome: SignInOutcome.returning);
      await tapGoogle(tester);

      expect(find.text('@dashboard'), findsOneWidget);
    });

    testWidgets('closing the Google sheet leaves the screen alone', (
      tester,
    ) async {
      final auth = await pumpLogin(tester, outcome: SignInOutcome.cancelled);
      await tapGoogle(tester);

      expect(auth.googleCalls, 1);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('@dashboard'), findsNothing);
      expect(find.text('@profileSetup'), findsNothing);
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: 'changing your mind is not an error worth a red banner',
      );
    });

    testWidgets('a real failure is shown to the parent', (tester) async {
      await pumpLogin(
        tester,
        failure: const AuthFailure('Sem conexão. Verifique sua internet.'),
      );
      await tapGoogle(tester);

      expect(find.text('Sem conexão. Verifique sua internet.'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('the sign-up screen offers the same providers', () {
    testWidgets('and a new account continues into onboarding', (tester) async {
      await pumpLogin(
        tester,
        outcome: SignInOutcome.created,
        home: const RegisterScreen(),
      );

      final button = find.byType(GoogleSignInButton);
      expect(button, findsOneWidget);
      expect(
        tester.widget<GoogleSignInButton>(button).label,
        'Criar conta com Google',
        reason: 'Google sanctions a distinct sign-up wording',
      );

      await tester.ensureVisible(button);
      await tapGoogle(tester);
      expect(find.text('@profileSetup'), findsOneWidget);
    });

    testWidgets('a parent who already has an account is just signed in', (
      tester,
    ) async {
      await pumpLogin(
        tester,
        outcome: SignInOutcome.returning,
        home: const RegisterScreen(),
      );
      await tester.ensureVisible(find.byType(GoogleSignInButton));
      await tapGoogle(tester);

      expect(
        find.text('@dashboard'),
        findsOneWidget,
        reason: 'the provider decides this, not the screen it was tapped from',
      );
    });
  });

  group('dismissal is told apart from failure', () {
    test('every platform spelling of "cancelled" counts as one', () {
      for (final code in signInCancellationCodes) {
        expect(isSignInCancellation(code), isTrue, reason: code);
      }
    });

    test('a genuine error does not', () {
      for (final code in [
        'network-request-failed',
        'account-exists-with-different-credential',
        'user-disabled',
      ]) {
        expect(isSignInCancellation(code), isFalse, reason: code);
      }
    });
  });

  test('the Google collision names the way out', () {
    expect(
      authErrorMessage('account-exists-with-different-credential'),
      'Este e-mail já tem uma conta. Entre com e-mail e senha.',
    );
  });

  test('demo mode shows the new-account path', () async {
    const repository = FakeAuthRepository();
    expect(await repository.signInWithGoogle(), SignInOutcome.created);
  });
}
