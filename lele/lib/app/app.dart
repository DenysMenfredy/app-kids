import 'package:flutter/material.dart';
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
      locale: const Locale('pt', 'BR'),
    );
  }
}
