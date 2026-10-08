import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lele/app/router/app_router.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/core/theme/app_theme.dart';
import 'package:lele/features/child_profile/presentation/profile_setup_screen.dart';
import 'package:lele/features/session/application/session_controller.dart';
import 'package:lele/features/session/data/profile_sync_service.dart';
import 'package:lele/features/session/domain/child_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RetryingProfileSyncService implements ProfileSyncService {
  final requestIds = <String>[];
  final profiles = <ChildProfile>[];

  @override
  Future<String> saveChildProfile({
    required ChildProfile profile,
    required String requestId,
    required String? existingChildId,
  }) async {
    requestIds.add(requestId);
    profiles.add(profile);
    if (requestIds.length == 1) throw StateError('temporary save failure');
    return 'server-child-id';
  }

  @override
  Future<void> syncParentName(String name) async {}

  @override
  Future<void> syncOnboardingState(String state) async {}
}

void main() {
  testWidgets(
    'a failed profile save retains inputs and retries the same request',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = _RetryingProfileSyncService();
      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (_, _) => const ProfileSetupScreen(),
          ),
          GoRoute(
            path: '/assessment',
            name: AppRoutes.assessmentIntro,
            builder: (_, _) => const Scaffold(body: Text('Assessment ready')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            sessionStorageScopeProvider.overrideWithValue('test-parent'),
            profileSyncServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Marina');
      await tester.tap(find.text('6'));
      await tester.tap(find.byType(AnimatedScale).at(2));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.text('Assessment ready'), findsNothing);
      expect(find.textContaining('Não foi possível salvar'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Marina',
      );
      expect(prefs.getString('session.test-parent.childName'), isNull);
      expect(
        service.profiles.single,
        const ChildProfile(name: 'Marina', age: 6, avatar: ChildAvatar.purple),
      );

      // The error snackbar overlaps the footer button, so its action must
      // provide a tappable retry while keeping the entered profile intact.
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('Assessment ready'), findsOneWidget);
      expect(find.textContaining('Não foi possível salvar'), findsNothing);
      expect(service.requestIds, hasLength(2));
      expect(service.requestIds.last, service.requestIds.first);
      expect(service.profiles.last, service.profiles.first);
      expect(prefs.getString('session.test-parent.childId'), 'server-child-id');
      expect(prefs.getString('session.test-parent.childName'), 'Marina');
      expect(
        prefs.getString('session.test-parent.childCreateRequestId'),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
