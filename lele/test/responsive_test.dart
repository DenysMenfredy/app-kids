import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/core/theme/app_theme.dart';
import 'package:lele/core/widgets/lele_button.dart';
import 'package:lele/features/assessment/presentation/assessment_intro_screen.dart';
import 'package:lele/features/assessment/presentation/assessment_question_screen.dart';
import 'package:lele/features/assessment/presentation/assessment_result_screen.dart';
import 'package:lele/features/auth/presentation/login_screen.dart';
import 'package:lele/features/auth/presentation/register_screen.dart';
import 'package:lele/features/books/presentation/books_screen.dart';
import 'package:lele/features/child_home/presentation/child_home_screen.dart';
import 'package:lele/features/child_profile/presentation/profile_setup_screen.dart';
import 'package:lele/features/dashboard/presentation/dashboard_screen.dart';
import 'package:lele/features/lesson/presentation/activities/listen_activity_screen.dart';
import 'package:lele/features/lesson/presentation/activities/match_activity_screen.dart';
import 'package:lele/features/lesson/presentation/activities/tap_activity_screen.dart';
import 'package:lele/features/lesson/presentation/activities/trace_activity_screen.dart';
import 'package:lele/features/lesson/presentation/lesson_intro_screen.dart';
import 'package:lele/features/onboarding/presentation/splash_screen.dart';
import 'package:lele/features/onboarding/presentation/welcome_screen.dart';
import 'package:lele/features/paywall/presentation/paywall_screen.dart';
import 'package:lele/features/reward/presentation/reward_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Logical sizes of the devices this app actually has to survive. The small
/// phone and the landscape rows are where fixed-height layouts break; the
/// folds are the awkward in-between the app was never designed for.
const devices = <String, Size>{
  'small phone (320x568)': Size(320, 568),
  'iPhone SE (375x667)': Size(375, 667),
  'Galaxy S21 (360x800)': Size(360, 800),
  'Pixel 5 (393x851)': Size(393, 851),
  'iPhone 15 Pro Max (430x932)': Size(430, 932),
  'Z Fold cover (344x882)': Size(344, 882),
  'Z Fold open (674x841)': Size(674, 841),
  'Pixel Fold open (841x701)': Size(841, 701),
  'iPad 10.2 (810x1080)': Size(810, 1080),
  'iPad Pro 12.9 (1024x1366)': Size(1024, 1366),
  'phone landscape (851x393)': Size(851, 393),
  'iPad landscape (1366x1024)': Size(1366, 1024),
};

Map<String, Widget Function()> get screens => {
      'splash': () => const SplashScreen(),
      'welcome': () => const WelcomeScreen(),
      'login': () => const LoginScreen(),
      'register': () => const RegisterScreen(),
      'profileSetup': () => const ProfileSetupScreen(),
      'assessmentIntro': () => const AssessmentIntroScreen(),
      'assessmentQuestion': () => const AssessmentQuestionScreen(),
      'assessmentResult': () => const AssessmentResultScreen(),
      'dashboard': () => const DashboardScreen(),
      'paywall': () => const PaywallScreen(),
      'childHome': () => const ChildHomeScreen(),
      'books': () => const BooksScreen(),
      'lessonIntro': () => const LessonIntroScreen(),
      'tapActivity': () => const TapActivityScreen(),
      'matchActivity': () => const MatchActivityScreen(),
      'traceActivity': () => const TraceActivityScreen(),
      'listenActivity': () => const ListenActivityScreen(),
      'reward': () => const RewardScreen(),
    };

/// Mounts one screen at one size and returns everything that went wrong.
Future<List<String>> audit(
  WidgetTester tester,
  String screen,
  Widget Function() build,
  Size size,
) async {
  final problems = <String>[];

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(theme: AppTheme.light, home: build()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));

  // Overflow is reported as a framework error, not a thrown exception.
  for (var error = tester.takeException();
      error != null;
      error = tester.takeException()) {
    var text = error.toString().split('\n').first.trim();
    if (text.startsWith('Multiple exceptions')) text = 'overflow';
    problems.add(text);
  }

  // The reported bug: the CTA sits past the bottom of the screen. That is
  // only a defect when nothing can scroll to it — below the fold inside a
  // scroll view is reachable, off the end of a fixed Column is a dead end.
  final viewport = Offset.zero & size;
  for (final element in find.byType(LeleButton).evaluate()) {
    final self = find.byElementPredicate((e) => e == element);
    final rect = tester.getRect(self);
    final label = _labelOf(element);
    final canScroll =
        find.ancestor(of: self, matching: find.byType(Scrollable)).evaluate().isNotEmpty;

    if (rect.bottom > viewport.bottom + 0.5 && !canScroll) {
      problems.add(
        'UNREACHABLE "$label" '
        '(${(rect.bottom - viewport.bottom).toStringAsFixed(0)}px below, nothing scrolls)',
      );
    }
    if (rect.right > viewport.right + 0.5 || rect.left < -0.5) {
      problems.add('button "$label" is cut off horizontally');
    }
  }

  return problems;
}

String _labelOf(Element element) {
  String? found;
  void visit(Element e) {
    if (found != null) return;
    final widget = e.widget;
    if (widget is Text && widget.data != null) {
      found = widget.data;
      return;
    }
    e.visitChildren(visit);
  }

  element.visitChildren(visit);
  return found ?? '?';
}

void main() {
  for (final device in devices.entries) {
    testWidgets('layout survives ${device.key}', (tester) async {
      addTearDown(tester.view.reset);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      final report = <String>[];
      for (final screen in screens.entries) {
        final problems =
            await audit(tester, screen.key, screen.value, device.value);
        for (final problem in problems) {
          // ignore: avoid_print
          print('FAILROW|${device.key}|${screen.key}|$problem');
          report.add('${screen.key}: $problem');
        }
      }

      expect(report, isEmpty, reason: '${device.key}:\n${report.join('\n')}');
    });
  }
}
