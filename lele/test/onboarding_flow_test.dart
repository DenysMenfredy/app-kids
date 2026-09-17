import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/app/app.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/core/widgets/lele_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpApp(WidgetTester tester) async {
  // Model a phone-sized viewport instead of the 800x600 default.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  // Looping mascot animations respect reduce-motion; disabling them lets
  // pumpAndSettle terminate.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const LeleApp(),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('splash screen shows brand and CTA', (tester) async {
    await pumpApp(tester);
    expect(find.text('Lelê'), findsOneWidget);
    expect(find.text('Aprender a ler brincando'), findsOneWidget);
    expect(find.text('Começar'), findsOneWidget);
  });

  testWidgets('parent completes onboarding to the dashboard', (tester) async {
    await pumpApp(tester);

    // Splash → welcome carousel.
    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();
    expect(find.text('Uma jornada diária de leitura'), findsOneWidget);

    // Walk the three slides.
    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(LeleButton, 'Criar conta'));
    await tester.pumpAndSettle();

    // Register (fake auth resolves after a short latency).
    expect(
      find.text('Conta para os pais — leva menos de 2 minutos.'),
      findsOneWidget,
    );
    // Every field is required now, so fill the form as a parent would.
    final registerFields = find.byType(TextField);
    await tester.enterText(registerFields.at(0), 'Camila');
    await tester.enterText(registerFields.at(1), 'camila@example.com');
    await tester.enterText(registerFields.at(2), 'segredo123');
    await tester.tap(find.widgetWithText(LeleButton, 'Criar conta'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Child profile.
    expect(find.text('Quem vai aprender?'), findsOneWidget);
    await tester.tap(find.widgetWithText(LeleButton, 'Continuar'));
    await tester.pumpAndSettle();

    // Assessment intro + 3 questions.
    await tester.tap(find.widgetWithText(LeleButton, 'Vamos lá'));
    await tester.pumpAndSettle();
    const firstOptions = ['Ainda não', 'Ainda não', 'Raramente'];
    for (var i = 0; i < firstOptions.length; i++) {
      expect(find.text('PERGUNTA ${i + 1} DE 3'), findsOneWidget);
      await tester.tap(find.text(firstOptions[i]).first);
      await tester.pumpAndSettle();
    }

    // Result → dashboard.
    expect(find.text('Jornada pronta!'), findsOneWidget);
    await tester.tap(find.widgetWithText(LeleButton, 'Ir para o painel'));
    await tester.pumpAndSettle();
    expect(find.text('Olá, Camila'), findsOneWidget);
    expect(find.text('Entrar no modo criança'), findsOneWidget);
  });
}
