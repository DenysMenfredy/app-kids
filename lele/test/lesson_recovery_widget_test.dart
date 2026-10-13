import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lele/app/router/app_router.dart';
import 'package:lele/core/audio/feedback_cues.dart';
import 'package:lele/core/services/feedback_service.dart';
import 'package:lele/core/services/tts_service.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/core/theme/app_theme.dart';
import 'package:lele/features/learning/application/journey_provider.dart';
import 'package:lele/features/lesson/application/lesson_session_controller.dart';
import 'package:lele/features/lesson/data/lesson_sync_service.dart';
import 'package:lele/features/lesson/domain/lesson_recovery.dart';
import 'package:lele/features/lesson/domain/lesson_reward.dart';
import 'package:lele/features/lesson/presentation/activities/listen_activity_screen.dart';
import 'package:lele/features/lesson/presentation/activities/match_activity_screen.dart';
import 'package:lele/features/lesson/presentation/lesson_intro_screen.dart';
import 'package:lele/features/session/application/child_provider.dart';
import 'package:lele/features/session/application/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_fonts.dart';

class _Tts extends TtsService {
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
}

class _Feedback implements FeedbackService {
  final cues = <FeedbackCue>[];
  @override
  Future<void> play(FeedbackCue cue) async {
    cues.add(cue);
  }

  @override
  Future<void> warmUp() async {}
  @override
  Future<void> dispose() async {}
}

class _Sync extends NoopLessonSyncService
    implements RecoverableLessonSyncService {
  int completions = 0;
  bool failCompletion = true;
  final attempts = <String>[];
  final starts = <String>[];
  PendingLesson? pending;
  @override
  Future<void> lessonStarted(
    String lessonId,
    String childId, {
    int? contentVersion,
  }) async {
    starts.add(lessonId);
  }

  @override
  Future<PendingLesson?> pendingLesson(String childId) async => pending;
  @override
  Future<LessonRecovery> recover(String childId) async => const LessonRecovery(
    lessonId: 'lesson_010',
    nextActivityIndex: 1,
    completedItems: {
      'activity_010_match': {'D'},
    },
    correctAnswers: 2,
    wrongAnswers: 1,
  );
  @override
  Future<void> discard(String childId) async {
    pending = null;
  }

  @override
  Future<void> clearLocalRecovery() async {
    pending = null;
  }

  @override
  Future<void> activityAttempt(
    String lessonId,
    String childId,
    String activityId,
    Map<String, Object?> response,
  ) async {
    expect(lessonId, 'lesson_010');
    expect(childId, 'child-a');
    attempts.add(activityId);
  }

  @override
  Future<LessonReward?> lessonCompleted(String lessonId, String childId) async {
    completions++;
    return failCompletion ? null : LessonReward.demo;
  }
}

void main() {
  setUpAll(loadAppFonts);
  Future<ProviderContainer> container(
    _Sync sync,
    _Feedback feedback, {
    String lesson = 'lesson_010',
  }) async {
    SharedPreferences.setMockInitialValues({});
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        lessonSyncServiceProvider.overrideWithValue(sync),
        ttsServiceProvider.overrideWithValue(_Tts()),
        feedbackServiceProvider.overrideWithValue(feedback),
        sessionStorageScopeProvider.overrideWithValue('parent-a'),
        activeChildIdProvider.overrideWithValue('child-a'),
        currentLessonIdProvider.overrideWithValue(lesson),
      ],
    );
  }

  GoRouter router(Widget initial) => GoRouter(
    routes: [
      GoRoute(
        path: '/',
        name: AppRoutes.lessonIntro,
        builder: (_, _) => initial,
      ),
      GoRoute(
        path: '/tap',
        name: AppRoutes.activityTap,
        builder: (_, _) => const Scaffold(body: Text('Tap restarted')),
      ),
      GoRoute(
        path: '/match',
        name: AppRoutes.activityMatch,
        builder: (_, _) => const MatchActivityScreen(),
      ),
      GoRoute(
        path: '/trace',
        name: AppRoutes.activityTrace,
        builder: (_, _) => const Scaffold(body: Text('Trace resumed')),
      ),
      GoRoute(
        path: '/reward',
        name: AppRoutes.reward,
        builder: (_, _) => const Scaffold(body: Text('Confirmed reward')),
      ),
      GoRoute(
        path: '/child',
        name: AppRoutes.childHome,
        builder: (_, _) => const Scaffold(),
      ),
    ],
  );

  for (final size in const [Size(390, 844), Size(320, 568)]) {
    testWidgets(
      'listen save failure stays recoverable and retry confirms on $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final sync = _Sync();
        final feedback = _Feedback();
        final scope = await container(sync, feedback);
        addTearDown(scope.dispose);
        expect(await scope.read(lessonSessionProvider).start(), isTrue);
        final navigation = router(const ListenActivityScreen());
        addTearDown(navigation.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: scope,
            child: MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: navigation,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.ensureVisible(find.text('DADO'));
        await tester.tap(find.text('DADO'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Confirmed reward'), findsNothing);
        expect(find.text('Tentar salvar novamente'), findsOneWidget);
        expect(feedback.cues, isNot(contains(FeedbackCue.celebrate)));
        sync.failCompletion = false;
        await tester.ensureVisible(find.text('Tentar salvar novamente'));
        await tester.tap(find.text('Tentar salvar novamente'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        expect(find.text('Confirmed reward'), findsOneWidget);
        expect(sync.attempts, ['activity_010_listen']);
        expect(sync.completions, 2);
        expect(feedback.cues.last, FeedbackCue.celebrate);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'intro can explicitly restart a pending run and open the first exercise',
    (tester) async {
      final sync = _Sync()
        ..pending = PendingLesson(
          childId: 'child-a',
          lessonId: 'lesson_010',
          requestId: 'start-a',
          createdAtMillis: DateTime.now().millisecondsSinceEpoch,
          contentVersion: 1,
        );
      final scope = await container(sync, _Feedback());
      addTearDown(scope.dispose);
      final navigation = router(const LessonIntroScreen());
      addTearDown(navigation.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: navigation,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Começar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Tap restarted'), findsOneWidget);
      expect(sync.pending, isNull);
      expect(sync.starts, ['lesson_010']);
      scope.read(lessonSessionProvider).leave();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'intro resumes the pending lesson and skips confirmed matching pairs',
    (tester) async {
      final sync = _Sync()
        ..pending = PendingLesson(
          childId: 'child-a',
          lessonId: 'lesson_010',
          requestId: 'start-a',
          createdAtMillis: DateTime.now().millisecondsSinceEpoch,
          contentVersion: 1,
        );
      final scope = await container(sync, _Feedback(), lesson: 'lesson_011');
      addTearDown(scope.dispose);
      final navigation = router(const LessonIntroScreen());
      addTearDown(navigation.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: navigation,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Continuar lição'), findsOneWidget);
      await tester.tap(find.text('Continuar lição'));
      await tester.pumpAndSettle();
      expect(find.text('Ligue as letras iguais'), findsOneWidget);
      expect(scope.read(lessonRunProvider)!.lessonId, 'lesson_010');
      await tester.tap(find.text('D'));
      await tester.tap(find.text('d'));
      await tester.pump();
      expect(sync.attempts, isEmpty);
      await tester.tap(find.text('T'));
      await tester.pump();
      await tester.tap(find.text('t'));
      await tester.pump();
      await tester.tap(find.text('B'));
      await tester.pump();
      await tester.tap(find.text('b'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Trace resumed'), findsOneWidget);
      expect(sync.attempts, ['activity_010_match', 'activity_010_match']);
      expect(tester.takeException(), isNull);
      scope.read(lessonSessionProvider).leave();
    },
  );
}
