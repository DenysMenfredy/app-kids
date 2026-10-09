import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lele/app/router/app_router.dart';
import 'package:lele/core/config/app_config.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/core/theme/app_theme.dart';
import 'package:lele/core/widgets/lele_button.dart';
import 'package:lele/features/child_profile/presentation/profile_setup_screen.dart';
import 'package:lele/features/dashboard/application/weekly_learning_provider.dart';
import 'package:lele/features/dashboard/domain/learning_week.dart';
import 'package:lele/features/dashboard/presentation/dashboard_screen.dart';
import 'package:lele/features/dashboard/presentation/weekly_learning_card.dart';
import 'package:lele/features/learning/application/journey_provider.dart';
import 'package:lele/features/learning/domain/learning_module.dart';
import 'package:lele/features/paywall/application/entitlement_provider.dart';
import 'package:lele/features/session/application/child_provider.dart';
import 'package:lele/features/session/application/parent_provider.dart';
import 'package:lele/features/session/application/progress_provider.dart';
import 'package:lele/features/session/application/session_controller.dart';
import 'package:lele/features/session/domain/child_profile.dart';
import 'package:lele/features/session/domain/child_record.dart';
import 'package:lele/features/session/domain/progress.dart';
import 'package:lele/features/session/presentation/child_profile_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_fonts.dart';

const _child = ChildRecord(
  id: 'real-child',
  profile: ChildProfile(name: 'Marina', age: 6, avatar: ChildAvatar.teal),
);

class _ChildrenFixture extends Notifier<AsyncValue<List<ChildRecord>>> {
  @override
  AsyncValue<List<ChildRecord>> build() => const AsyncData([]);

  void set(AsyncValue<List<ChildRecord>> value) => state = value;
}

final _childrenFixture =
    NotifierProvider<_ChildrenFixture, AsyncValue<List<ChildRecord>>>(
      _ChildrenFixture.new,
    );

Future<ProviderContainer> _container(
  AsyncValue<List<ChildRecord>> children, {
  bool dashboardFixture = false,
}) async {
  // The stale local selection must never substitute for the account's list.
  SharedPreferences.setMockInitialValues({
    'session.parent-a.childName': 'Sofia',
    'session.parent-a.childId': 'deleted-child',
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      sessionStorageScopeProvider.overrideWithValue('parent-a'),
      remoteChildrenProvider.overrideWith((ref) => ref.watch(_childrenFixture)),
      if (dashboardFixture) ...[
        // Exercise the real Firebase selection resolver also in demo-mode CI.
        selectedChildStateProvider.overrideWith(
          (ref) => resolveSelectedChild(
            ref.watch(remoteChildrenProvider),
            ref.watch(sessionProvider).childId,
          ),
        ),
        parentFirstNameProvider.overrideWithValue('Denys'),
        isPremiumProvider.overrideWithValue(false),
        progressProvider.overrideWithValue(Progress.zero),
        journeyProvider.overrideWithValue(
          resolveJourney(curriculum.first.firstLessonId),
        ),
        weeklyLearningProvider.overrideWithValue(
          AsyncData(LearningWeek.empty(DateTime(2026, 10, 9))),
        ),
      ],
    ],
  );
  container.read(_childrenFixture.notifier).set(children);
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpDashboard(
  WidgetTester tester,
  ProviderContainer container,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/dashboard',
        name: AppRoutes.dashboard,
        builder: (_, _) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        name: AppRoutes.profileSetup,
        builder: (_, state) => ProfileSetupScreen(
          createNew: state.uri.queryParameters['new'] == 'true',
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pump();
}

void _expectNoChildContent() {
  expect(find.textContaining('Sofia'), findsNothing);
  expect(find.textContaining('Marina'), findsNothing);
  expect(find.text('Entrar no modo criança'), findsNothing);
  expect(find.text('Jornada de aprendizado'), findsNothing);
  expect(find.byType(WeeklyLearningCard), findsNothing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  group('selection resolution', () {
    test('empty remote list never invents a cached/default child', () {
      final selected = resolveSelectedChild(
        const AsyncData([]),
        'deleted-child',
      );
      expect(selected.hasValue, isTrue);
      expect(selected.requireValue, isNull);
    });
    test('uses only surviving real profiles for selection fallback', () {
      const primary = ChildRecord(
        id: 'primary',
        profile: ChildProfile.defaultProfile,
      );
      expect(
        resolveSelectedChild(
          const AsyncData([_child]),
          'deleted-child',
        ).requireValue,
        _child,
      );
      expect(
        resolveSelectedChild(
          const AsyncData([_child, primary]),
          'deleted-child',
        ).requireValue,
        primary,
      );
      expect(
        resolveSelectedChild(
          const AsyncData([_child, primary]),
          _child.id,
        ).requireValue,
        _child,
      );
    });
    test(
      'loading/error do not expose a prior snapshot as a selected child',
      () async {
        final stream = StreamController<List<ChildRecord>>.broadcast();
        final provider = StreamProvider<List<ChildRecord>>(
          (ref) => stream.stream,
        );
        final container = ProviderContainer();
        addTearDown(stream.close);
        addTearDown(container.dispose);
        container.listen(provider, (_, _) {});
        stream.add([_child]);
        await container.read(provider.future);
        // A real Riverpod refresh retains its previous value while loading.
        container.invalidate(provider);
        final loading = container.read(provider);
        expect(loading.value, [_child]);
        expect(resolveSelectedChild(loading, _child.id).isLoading, isTrue);
        expect(resolveSelectedChild(loading, _child.id).value, isNull);
        stream.addError(StateError('offline'), StackTrace.empty);
        await Future<void>.delayed(Duration.zero);
        final error = container.read(provider);
        expect(resolveSelectedChild(error, _child.id).hasError, isTrue);
        expect(resolveSelectedChild(error, _child.id).value, isNull);
      },
    );
  });

  test(
    'Firebase ignores cached Sofia on empty, loading, and failed reads',
    () async {
      final container = await _container(const AsyncData([]));
      for (final state in <AsyncValue<List<ChildRecord>>>[
        const AsyncData([]),
        const AsyncLoading(),
        AsyncError(StateError('offline'), StackTrace.empty),
      ]) {
        container.read(_childrenFixture.notifier).set(state);
        expect(
          container.read(childProvider).name,
          AppConfig.useFirebase ? '' : 'Sofia',
        );
        if (AppConfig.useFirebase) {
          expect(container.read(remoteChildProvider), isNull);
        }
      }
      container.read(_childrenFixture.notifier).set(const AsyncData([_child]));
      expect(
        container.read(childProvider).name,
        AppConfig.useFirebase ? 'Marina' : 'Sofia',
      );
    },
  );

  testWidgets(
    'empty dashboard and profile sheet agree; add form starts blank',
    (tester) async {
      final container = await _container(
        const AsyncData([]),
        dashboardFixture: true,
      );
      await _pumpDashboard(tester, container);
      _expectNoChildContent();
      expect(find.text('Nenhum perfil cadastrado ainda.'), findsOneWidget);
      expect(find.text('Adicionar criança'), findsOneWidget);
      if (AppConfig.useFirebase) {
        await tester.tap(find.text('Perfis das crianças'));
        await tester.pumpAndSettle();
        expect(find.text('Nenhum perfil cadastrado ainda.'), findsNWidgets(2));
        await tester.tap(
          find.widgetWithText(LeleButton, 'Adicionar criança').last,
        );
      } else {
        await tester.tap(find.text('Adicionar criança'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Quem vai aprender?'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Informe o nome da criança.'), findsOneWidget);
      expect(find.text('Quem vai aprender?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loading and failure do not claim the family has no children', (
    tester,
  ) async {
    final container = await _container(
      const AsyncLoading(),
      dashboardFixture: true,
    );
    await _pumpDashboard(tester, container);
    _expectNoChildContent();
    expect(find.text('Nenhum perfil cadastrado ainda.'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<LeleButton>(find.byType(LeleButton)).enabled, isFalse);
    container
        .read(_childrenFixture.notifier)
        .set(AsyncError(StateError('offline'), StackTrace.empty));
    await tester.pump();
    _expectNoChildContent();
    expect(find.text('Não foi possível carregar os perfis.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('Nenhum perfil cadastrado ainda.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'removing the last real child removes child-specific dashboard content',
    (tester) async {
      final container = await _container(
        const AsyncData([_child]),
        dashboardFixture: true,
      );
      await _pumpDashboard(tester, container);
      expect(find.text('Marina · 6 anos'), findsOneWidget);
      expect(find.byType(WeeklyLearningCard), findsOneWidget);
      expect(find.text('Entrar no modo criança'), findsOneWidget);
      container.read(_childrenFixture.notifier).set(const AsyncData([]));
      await tester.pump();
      _expectNoChildContent();
      expect(find.text('Adicionar criança'), findsOneWidget);
      if (AppConfig.useFirebase) {
        expect(container.read(sessionProvider).child.name, isEmpty);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a child-only route cannot build without a real selected profile',
    (tester) async {
      final container = await _container(
        const AsyncData([]),
        dashboardFixture: true,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ChildProfileGate(child: Text('Child-only content')),
          ),
        ),
      );
      expect(find.text('Child-only content'), findsNothing);
      expect(find.text('Adicionar criança'), findsOneWidget);
      container.read(_childrenFixture.notifier).set(const AsyncData([_child]));
      await tester.pump();
      expect(find.text('Child-only content'), findsOneWidget);
      container.read(_childrenFixture.notifier).set(const AsyncData([]));
      await tester.pump();
      expect(find.text('Child-only content'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
