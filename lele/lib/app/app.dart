import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/layout/adaptive_page.dart';
import '../core/theme/app_theme.dart';
import 'router/app_router.dart';

class LeleApp extends ConsumerWidget {
  const LeleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Lelê',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: adaptiveTextScaler(context)),
        child: child!,
      ),
      routerConfig: router,
      // The app is pt-BR only, but declaring the locale without these
      // delegates left Flutter's own chrome — the text selection menu, the
      // semantics vocabulary a screen reader reads out — falling back to
      // English, so a Brazilian parent long-pressing the e-mail field was
      // offered "Paste" rather than "Colar".
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
