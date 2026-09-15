import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  Size size, {
  double textScale = 1.0,
}) async {
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
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          // What the device's font-size setting actually does to the app.
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: build(),
      ),
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

    // A call to action that wraps onto a second line is the "text is too
    // big" complaint in its most measurable form.
    final labels = find.descendant(of: self, matching: find.byType(Text));
    for (final labelEl in labels.evaluate()) {
      final para = labelEl.renderObject;
      final text = labelEl.widget;
      if (para is RenderParagraph && text is Text && (text.data ?? '').isNotEmpty) {
        // Distinct box tops == distinct rendered lines.
        final boxes = para.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.data!.length),
        );
        final lines = boxes.map((b) => b.top.round()).toSet().length;
        // One line is the goal; two is the deliberate fallback for a label
        // too long to shrink politely. Three is the reported bug.
        if (lines > 2) {
          problems.add('button label "$label" wraps onto $lines lines');
        }
        // And shrink-to-fit must not be allowed to solve wrapping by making
        // the label unreadable.
        if (lines == 1) {
          final natural = para.getMaxIntrinsicWidth(double.infinity);
          final available = rect.width - 36;
          final ratio = natural <= available ? 1.0 : available / natural;
          if (ratio < 0.75) {
            problems.add('button label "$label" shrunk to '
                '${ratio.toStringAsFixed(2)}x — below legibility');
          }
        }
      }
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

/// 1.0 is the default; 1.3 is Android's largest non-accessibility setting
/// and iOS's larger sizes, which plenty of parents run day to day.
const textScales = <double>[1.0, 1.3, 1.6, 2.0];

/// Widget tests use a fallback font whose glyphs are far wider than Baloo 2.
/// Measuring text against it would exaggerate every wrap and shrink, so load
/// the real bundled faces before measuring anything.
Future<void> loadAppFonts() async {
  for (final family in const {
    'Baloo 2': ['Baloo2-Bold.ttf', 'Baloo2-ExtraBold.ttf'],
    'Nunito': ['Nunito-Bold.ttf', 'Nunito-SemiBold.ttf', 'Nunito-Regular.ttf'],
  }.entries) {
    final loader = FontLoader(family.key);
    for (final file in family.value) {
      final bytes = File('assets/fonts/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(loadAppFonts);

  for (final device in devices.entries) {
    for (final scale in textScales) {
      testWidgets('layout survives ${device.key} at text scale $scale',
          (tester) async {
        addTearDown(tester.view.reset);
        addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

        final report = <String>[];
        for (final screen in screens.entries) {
          final problems = await audit(
              tester, screen.key, screen.value, device.value,
              textScale: scale);
          for (final problem in problems) {
            // ignore: avoid_print
            print('FAILROW|${device.key} @${scale}x|${screen.key}|$problem');
            report.add('${screen.key}: $problem');
          }
        }

        expect(report, isEmpty,
            reason: '${device.key} @${scale}x:\n${report.join('\n')}');
      });
    }
  }
}
