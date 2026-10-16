import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/layout/adaptive_page.dart';
import '../core/theme/app_theme.dart';
import '../features/dashboard/application/weekly_learning_provider.dart';
import '../features/lesson/application/lesson_session_controller.dart';
import '../features/notifications/application/notification_controller.dart';
import 'router/app_router.dart';

class LeleApp extends ConsumerStatefulWidget {
  const LeleApp({super.key});
  @override
  ConsumerState<LeleApp> createState() => _LeleAppState();
}

class _LeleAppState extends ConsumerState<LeleApp> with WidgetsBindingObserver {
  late final GoRouter _router;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = ref.read(appRouterProvider);
    _router.routeInformationProvider.addListener(_routeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifications = ref.read(notificationControllerProvider);
      notifications.onOpen = () => _router.goNamed(AppRoutes.dashboard);
      notifications.refresh();
    });
  }

  void _routeChanged() {
    if (!_router.routeInformationProvider.value.uri.path.startsWith(
      '/lesson',
    )) {
      ref.read(lessonSessionProvider).leave();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref
        .read(lessonSessionProvider)
        .setForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(weeklyLearningQueryProvider);
      ref.read(notificationControllerProvider).refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.routeInformationProvider.removeListener(_routeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
