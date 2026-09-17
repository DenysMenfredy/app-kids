import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/layout/adaptive_page.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/core/theme/app_theme.dart';
import 'package:lele/features/dashboard/presentation/dashboard_screen.dart';
import 'package:lele/features/session/application/parent_provider.dart';
import 'package:lele/features/session/application/session_controller.dart';
import 'package:lele/features/session/domain/parent_name.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  group('firstNameOf', () {
    test('takes the first word of a full name', () {
      expect(firstNameOf('Denys Menfredy'), 'Denys');
      expect(firstNameOf('Maria da Silva Souza'), 'Maria');
    });

    test('leaves a single name alone', () {
      expect(firstNameOf('Fabiola'), 'Fabiola');
    });

    test('keeps hyphens and accents inside the first name', () {
      expect(firstNameOf('Ana-Paula Souza'), 'Ana-Paula');
      expect(firstNameOf('Thaís Gonçalves'), 'Thaís');
    });

    test('survives padding and repeated separators', () {
      expect(firstNameOf('  Denys   Menfredy  '), 'Denys');
      expect(firstNameOf('Denys\tMenfredy'), 'Denys');
    });

    test('is empty when the name is not known yet', () {
      expect(firstNameOf(''), '');
      expect(firstNameOf('   '), '');
    });
  });

  group('the stored name and the greeting are different things', () {
    Future<ProviderContainer> container() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('registering a full name keeps every part of it', () async {
      final c = await container();
      c.read(sessionProvider.notifier).setParentName('Denys Menfredy');

      expect(
        c.read(parentNameProvider),
        'Denys Menfredy',
        reason: 'the record — and what the backend stores — is the full name',
      );
      expect(c.read(parentFirstNameProvider), 'Denys');
    });

    test('a surname added later does not change the greeting', () async {
      final c = await container();
      c.read(sessionProvider.notifier).setParentName('Denys');
      expect(c.read(parentFirstNameProvider), 'Denys');

      c.read(sessionProvider.notifier).setParentName('Denys Menfredy');
      expect(c.read(parentFirstNameProvider), 'Denys');
      expect(c.read(parentNameProvider), 'Denys Menfredy');
    });
  });

  Future<void> pumpDashboard(
    WidgetTester tester,
    String storedName, {
    Size size = const Size(430, 932),
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    SharedPreferences.setMockInitialValues({'session.parentName': storedName});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: AppTheme.light,
          // The requested system scale, then the app's own clamp on top —
          // which is what a parent actually sees.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: adaptiveTextScaler(context)),
                child: child!,
              ),
            ),
          ),
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// How many lines the greeting actually rendered on. Distinct box tops
  /// are distinct lines — the same measure `responsive_test.dart` uses for
  /// button labels.
  int greetingLines(WidgetTester tester) {
    final finder = find.textContaining('Olá');
    final paragraph = tester.renderObject<RenderParagraph>(finder);
    final label = tester.widget<Text>(finder).data!;
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: label.length),
    );
    return boxes.map((b) => b.top.round()).toSet().length;
  }

  testWidgets('the dashboard greets by first name only', (tester) async {
    await pumpDashboard(tester, 'Denys Menfredy');

    expect(find.text('Olá, Denys'), findsOneWidget);
    expect(find.text('Olá, Denys Menfredy'), findsNothing);
    expect(greetingLines(tester), 1);
  });

  /// The header sits above a fixed stack of cards; a greeting that wraps
  /// pushes every one of them down the screen.
  group('the greeting never wraps', () {
    const names = [
      'Denys Menfredy',
      'Ana-Paula Souza Lima',
      'Maria',
      'Wolfeschlegelsteinhausenbergerdorff',
      '',
    ];

    for (final name in names) {
      final label = name.isEmpty ? '(no name yet)' : name;
      testWidgets('one line for "$label" on a small phone', (tester) async {
        await pumpDashboard(tester, name, size: const Size(320, 568));
        expect(greetingLines(tester), 1);
      });

      testWidgets('one line for "$label" at a large text scale', (
        tester,
      ) async {
        await pumpDashboard(
          tester,
          name,
          size: const Size(320, 568),
          textScale: 1.3,
        );
        expect(greetingLines(tester), 1);
      });
    }
  });
}
