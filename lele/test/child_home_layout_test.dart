import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/core/theme/app_theme.dart';
import 'package:lele/features/child_home/presentation/child_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_fonts.dart';

Future<void> pumpChildHome(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(theme: AppTheme.light, home: const ChildHomeScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(loadAppFonts);

  /// Reported from an iPhone 14 Pro Max: the three stat pills rendered as
  /// full-width bars stacked down the screen. Their inner `Row` defaulted to
  /// `MainAxisSize.max`, so inside the `Wrap` each one claimed the whole
  /// line. The `Wrap` is there to let them fall onto a second row on a small
  /// phone, which only reads as wrapping if they are chip-sized to begin
  /// with.
  testWidgets('the stat pills sit together, not stacked full-width', (
    tester,
  ) async {
    await pumpChildHome(tester, const Size(430, 932));

    final wrap = find.byType(Wrap);
    expect(wrap, findsOneWidget);

    final wrapSize = tester.getSize(wrap);
    expect(
      wrapSize.height,
      lessThan(60),
      reason: 'the pills should occupy one row, not one row each',
    );

    // Every pill must be narrower than the space they share.
    final pills = find.descendant(
      of: wrap,
      matching: find.byType(DecoratedBox),
    );
    expect(pills, findsWidgets);
    for (final pill in pills.evaluate()) {
      final width = tester
          .getSize(find.byElementPredicate((e) => e == pill))
          .width;
      expect(
        width,
        lessThan(wrapSize.width * 0.6),
        reason: 'a stat pill grew to fill the row',
      );
    }
  });

  testWidgets('the pills still fit on a small phone', (tester) async {
    await pumpChildHome(tester, const Size(320, 568));
    // Two rows at most: wrapping is the point, stacking three-high is not.
    expect(tester.getSize(find.byType(Wrap)).height, lessThan(110));
  });
}
