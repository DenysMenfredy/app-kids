import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/core/theme/app_theme.dart';
import 'package:lele/features/auth/data/auth_repository.dart';
import 'package:lele/features/auth/presentation/apple_sign_in_button.dart';
import 'package:lele/features/auth/presentation/google_sign_in_button.dart';
import 'package:lele/features/auth/presentation/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

Future<void> pumpButton(WidgetTester tester, {bool enabled = true}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: AppleSignInButton(onPressed: enabled ? () {} : null),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The framework checks that no foundation debug variable is still set when
/// a test body returns, so the override has to be unwound inside the body
/// rather than in a tearDown.
Future<void> onPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  group('where it appears', () {
    testWidgets('on iOS', (tester) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await pumpButton(tester);
        expect(find.byType(SignInWithAppleButton), findsOneWidget);
      });
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
      testWidgets('not on $platform', (tester) async {
        await onPlatform(platform, () async {
          await pumpButton(tester);
          expect(
            find.byType(SignInWithAppleButton),
            findsNothing,
            reason: 'the button was asked for on iOS only',
          );
          // And takes up no room when it is not offered.
          expect(tester.getSize(find.byType(AppleSignInButton)).height, 0);
        });
      });
    }
  });

  group('built to the guidelines', () {
    testWidgets('scales Apple\'s button rather than redrawing its mark', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await pumpButton(tester);
        final button = tester.widget<SignInWithAppleButton>(
          find.byType(SignInWithAppleButton),
        );

        // Apple's own proportions follow from the height, so scaling to match
        // the Google button beside it keeps the type and logo correct.
        expect(button.height, 54);
        expect(button.style, SignInWithAppleButtonStyle.black);
        expect(
          button.borderRadius,
          const BorderRadius.all(Radius.circular(18)),
          reason: 'Apple allows a radius matching the rest of the UI',
        );
      });
    });

    testWidgets('translates the action but never the brand', (tester) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await pumpButton(tester);
        final button = tester.widget<SignInWithAppleButton>(
          find.byType(SignInWithAppleButton),
        );
        expect(button.text, 'Continuar com Apple');
        expect(
          button.text.endsWith('Apple'),
          isTrue,
          reason: '"Apple" is a brand name and is never localised',
        );
      });
    });

    testWidgets('announces itself once, and reports being disabled', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.iOS, () async {
        final handle = tester.ensureSemantics();

        await pumpButton(tester);
        expect(find.bySemanticsLabel('Continuar com Apple'), findsOneWidget);

        await pumpButton(tester, enabled: false);
        expect(
          tester.getSemantics(find.byType(AppleSignInButton)),
          isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
        );
        handle.dispose();
      });
    });

    testWidgets('is big enough to hit', (tester) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await pumpButton(tester);
        expect(
          tester.getSize(find.byType(SignInWithAppleButton)).height,
          greaterThanOrEqualTo(44),
          reason: "Apple's own default height is 44pt",
        );
      });
    });
  });

  /// Review guideline 4.8: where another third-party sign-in is offered,
  /// Sign in with Apple has to be offered on equivalent terms. Same size,
  /// same shape, side by side — so a restyle of one button cannot quietly
  /// demote the other.
  testWidgets('on iOS both sign-in options are equally prominent', (
    tester,
  ) async {
    await onPlatform(TargetPlatform.iOS, () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(430, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
        ),
      );
      await tester.pump();

      final apple = find.byType(AppleSignInButton);
      final google = find.byType(GoogleSignInButton);
      expect(apple, findsOneWidget);
      expect(google, findsOneWidget);

      final appleRect = tester.getRect(apple);
      final googleRect = tester.getRect(google);
      expect(appleRect.width, moreOrLessEquals(googleRect.width, epsilon: 0.5));
      expect(
        appleRect.height,
        moreOrLessEquals(googleRect.height, epsilon: 0.5),
      );
      expect(
        (googleRect.top - appleRect.bottom).abs(),
        lessThan(24),
        reason: 'the two options must sit together, not in separate regions',
      );
    });
  });

  test('the offline fake answers for Apple too', () async {
    const repository = FakeAuthRepository();
    await expectLater(repository.signInWithApple(), completes);
  });
}
