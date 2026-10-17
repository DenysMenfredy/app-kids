import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/widgets/lele_button.dart';
import 'package:lele/features/paywall/presentation/paywall_screen.dart';

void main() {
  testWidgets('a beta without checkout does not offer an active trial', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: PaywallScreen())),
    );

    expect(find.text('Assinaturas em breve'), findsOneWidget);
    expect(find.text('Começar teste grátis de 7 dias'), findsNothing);
    expect(find.text('PREÇO DE FUNDADOR'), findsNothing);
    expect(find.textContaining('R\$'), findsNothing);
    expect(find.textContaining('Google Play ou App Store'), findsWidgets);
    final button = tester.widget<LeleButton>(
      find.widgetWithText(LeleButton, 'Assinaturas em breve'),
    );
    expect(button.enabled, isFalse);
  });
}
