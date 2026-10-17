import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/core/theme/app_spacing.dart';
import 'package:lele/core/theme/app_theme.dart';
import 'package:lele/core/widgets/lele_card.dart';
import 'package:lele/core/widgets/lele_icon_button.dart';
import 'package:lele/features/books/presentation/books_screen.dart';
import 'package:lele/features/child_home/presentation/child_home_screen.dart';
import 'package:lele/features/dashboard/presentation/dashboard_screen.dart';
import 'package:lele/features/paywall/application/store_catalog_provider.dart';
import 'package:lele/features/paywall/domain/plan.dart';
import 'package:lele/features/paywall/presentation/paywall_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_fonts.dart';

/// Widths that between them expose the whole class of bug below. A single
/// width is not enough: at 430 the status chip's width in the test font
/// happened to equal its flex share exactly, so the dashboard header
/// measured perfectly aligned while the real build was 81px out.
const widths = [320.0, 375.0, 430.0, 600.0, 834.0];

Future<void> pump(WidgetTester tester, Widget screen, double width) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // A store-localized fixture, never the production fallback catalog.
        storeCatalogProvider.overrideWithValue(const [
          Plan(
            id: 'monthly',
            name: 'Mensal',
            subtitle: 'Por mês',
            price: r'R$ 19,90',
          ),
        ]),
      ],
      child: MaterialApp(theme: AppTheme.light, home: screen),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// The painted square of an icon button, as opposed to its touch area.
Rect paintedBox(WidgetTester tester, Finder button) => tester.getRect(
  find.descendant(of: button, matching: find.byType(Container)).first,
);

void main() {
  setUpAll(loadAppFonts);

  /// A `Row` holding both an `Expanded` and a `Flexible` splits its free
  /// space between them. The `Flexible` child draws only as wide as its
  /// content and the rest of its share becomes dead space at the end of the
  /// row — pushing whatever sits last away from the margin. It is invisible
  /// on a narrow screen and grows with the viewport, so every one of these
  /// is checked across widths.
  group('the last thing in a row reaches the margin', () {
    for (final width in widths) {
      testWidgets('dashboard sign-out, at ${width.toInt()}', (tester) async {
        await pump(tester, const DashboardScreen(), width);

        final button = find.byType(LeleIconButton);
        final cardRight = tester.getRect(find.byType(LeleCard).first).right;

        expect(
          paintedBox(tester, button).right,
          moreOrLessEquals(cardRight, epsilon: 0.5),
          reason: 'the sign-out button must reach the same margin as the cards',
        );
        // The touch target must survive the alignment fix.
        expect(
          tester.getSize(button).width,
          greaterThanOrEqualTo(AppSpacing.minTapTarget),
        );
      });

      testWidgets('paywall price, at ${width.toInt()}', (tester) async {
        await pump(tester, const PaywallScreen(), width);

        final price = find.text('R\$ 19,90');
        final row = find.ancestor(of: price, matching: find.byType(Row)).first;
        expect(
          tester.getRect(price).right,
          moreOrLessEquals(tester.getRect(row).right, epsilon: 0.5),
          reason: 'the price must sit against the edge of its plan card',
        );
      });
    }
  });

  group('an icon button against a left margin', () {
    for (final width in widths) {
      testWidgets('child home menu, at ${width.toInt()}', (tester) async {
        await pump(tester, const ChildHomeScreen(), width);
        final button = find.byType(LeleIconButton).first;
        expect(
          paintedBox(tester, button).left,
          moreOrLessEquals(20, epsilon: 0.5),
        );
        expect(
          tester.getSize(button).width,
          greaterThanOrEqualTo(AppSpacing.minTapTarget),
        );
      });

      testWidgets('books back, at ${width.toInt()}', (tester) async {
        await pump(tester, const BooksScreen(), width);
        final button = find.byType(LeleIconButton).first;
        expect(
          paintedBox(tester, button).left,
          moreOrLessEquals(24, epsilon: 0.5),
        );
      });
    }
  });
}
