import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/features/auth/presentation/google_sign_in_button.dart';

/// Google's published specification, restated here so a future restyle of
/// the app cannot quietly drag this button along with it.
/// <https://developers.google.com/identity/branding-guidelines>
const _fill = Color(0xFFFFFFFF);
const _stroke = Color(0xFF747775);
const _textColor = Color(0xFF1F1F1F);

/// The only three actions Google sanctions, in any language.
const _sanctionedActions = ['Continuar com', 'Entrar com', 'Criar conta com'];

Future<void> pumpButton(
  WidgetTester tester, {
  // A nullable callback cannot express "disabled" here: `?? () {}` would
  // swallow it, which is exactly what made an earlier version of the
  // disabled test pass against a live button.
  bool enabled = true,
  String? label,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: GoogleSignInButton(
              onPressed: enabled ? () {} : null,
              label: label ?? 'Continuar com Google',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows Google\'s own mark, not a lookalike', (tester) async {
    await pumpButton(tester);

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as AssetImage;
    expect(
      provider.assetName,
      'assets/images/google/g_logo.png',
      reason: 'the mark must be the asset Google ships',
    );

    // The button this replaced drew the brand colours as a sweep gradient.
    // Recreating the mark is explicitly forbidden.
    final decorations = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>();
    for (final decoration in decorations) {
      expect(
        decoration.gradient,
        isNull,
        reason: 'a gradient here means someone is drawing the logo again',
      );
    }
  });

  testWidgets('the asset actually resolves and is square', (tester) async {
    await pumpButton(tester);
    await tester.runAsync(() async {
      final image = tester.widget<Image>(find.byType(Image));
      // Throws if the asset is missing from the bundle — which is what a
      // forgotten pubspec entry looks like at runtime.
      await precacheImage(image.image, tester.element(find.byType(Image)));
    });

    final size = tester.getSize(find.byType(Image));
    expect(size.width, 20);
    expect(
      size.height,
      size.width,
      reason: 'a non-square box would stretch the mark',
    );
  });

  testWidgets('uses Google\'s light-theme colours, not the app palette', (
    tester,
  ) async {
    await pumpButton(tester);

    final container = tester.widget<Container>(
      find
          .ancestor(of: find.byType(Image), matching: find.byType(Container))
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.color, _fill);
    final border = decoration.border! as Border;
    expect(border.top.color, _stroke);
    expect(border.top.width, 1);
    expect(
      border.top.strokeAlign,
      BorderSide.strokeAlignInside,
      reason: 'an outside stroke eats the logo\'s clear space',
    );

    final text = tester.widget<Text>(find.byType(Text));
    expect(text.style!.color, _textColor);
    expect(text.style!.fontSize, 14);
    expect(text.style!.height, 20 / 14, reason: '14/20 type');
    expect(
      text.style!.fontFamily,
      isNull,
      reason: 'falls back to the platform UI font, never a Lelê display face',
    );
  });

  testWidgets('keeps the 12 / 10 / 12 metrics', (tester) async {
    await pumpButton(tester);

    final buttonRect = tester.getRect(find.byType(GestureDetector));
    final logoRect = tester.getRect(find.byType(Image));
    final textRect = tester.getRect(find.byType(Text));

    expect(logoRect.left - buttonRect.left, greaterThanOrEqualTo(12));
    expect(buttonRect.right - textRect.right, greaterThanOrEqualTo(12));
    expect(textRect.left - logoRect.right, moreOrLessEquals(10, epsilon: 0.5));
  });

  testWidgets('says one of the things Google allows it to say', (tester) async {
    await pumpButton(tester);
    final label = tester.widget<Text>(find.byType(Text)).data!;
    expect(label.endsWith('Google'), isTrue);
    expect(
      _sanctionedActions.any(label.startsWith),
      isTrue,
      reason: '"$label" is not a sanctioned action',
    );
  });

  testWidgets('is announced once, and is big enough to hit', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpButton(tester);

    expect(find.bySemanticsLabel('Continuar com Google'), findsOneWidget);
    expect(
      tester.getSize(find.byType(GestureDetector)).height,
      greaterThanOrEqualTo(48),
    );
    handle.dispose();
  });

  testWidgets('a disabled button reports itself as disabled', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpButton(tester, enabled: false);

    expect(
      tester.getSemantics(find.byType(GoogleSignInButton)),
      isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      reason: 'a sign-in already in flight must not look tappable',
    );
    handle.dispose();
  });
}
