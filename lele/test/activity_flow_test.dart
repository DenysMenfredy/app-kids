import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lele/app/router/app_router.dart';
import 'package:lele/core/audio/feedback_cues.dart';
import 'package:lele/core/services/feedback_service.dart';
import 'package:lele/core/services/tts_service.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/core/theme/app_spacing.dart';
import 'package:lele/core/theme/app_theme.dart';
import 'package:lele/core/widgets/lele_button.dart';
import 'package:lele/core/widgets/lele_icon_button.dart';
import 'package:lele/features/lesson/application/lesson_stats_controller.dart';
import 'package:lele/features/lesson/presentation/activities/listen_activity_screen.dart';
import 'package:lele/features/lesson/presentation/activities/match_activity_screen.dart';
import 'package:lele/features/lesson/presentation/activities/tap_activity_screen.dart';
import 'package:lele/features/lesson/presentation/activities/trace_activity_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the cues instead of making a noise. Also keeps the suite off the
/// platform audio stack, which no test runner has.
class RecordingFeedback implements FeedbackService {
  final played = <FeedbackCue>[];

  @override
  Future<void> play(FeedbackCue cue) async => played.add(cue);

  @override
  Future<void> warmUp() async {}

  @override
  Future<void> dispose() async {}
}

/// Speaks into a list instead of at a platform channel.
class RecordingTts extends TtsService {
  final spoken = <String>[];

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> warmUp() async {}

  @override
  Future<void> stop() async {}
}

/// The four activities at their real route names, so the hand-off between
/// them is the one the app performs. The screens the lesson exits to are
/// stubbed: what matters here is that the child arrives.
GoRouter _router(String initialLocation) {
  Widget stub(String name) => Scaffold(body: Center(child: Text('@$name')));
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/lesson',
        name: AppRoutes.lessonIntro,
        builder: (context, state) => stub('lessonIntro'),
        routes: [
          GoRoute(
            path: 'tap',
            name: AppRoutes.activityTap,
            builder: (context, state) => const TapActivityScreen(),
          ),
          GoRoute(
            path: 'match',
            name: AppRoutes.activityMatch,
            builder: (context, state) => const MatchActivityScreen(),
          ),
          GoRoute(
            path: 'trace',
            name: AppRoutes.activityTrace,
            builder: (context, state) => const TraceActivityScreen(),
          ),
          GoRoute(
            path: 'listen',
            name: AppRoutes.activityListen,
            builder: (context, state) => const ListenActivityScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/reward',
        name: AppRoutes.reward,
        builder: (context, state) => stub('reward'),
      ),
      GoRoute(
        path: '/child',
        name: AppRoutes.childHome,
        builder: (context, state) => stub('childHome'),
      ),
    ],
  );
}

class Harness {
  Harness(this.container, this.tts, this.feedback);

  final ProviderContainer container;
  final RecordingTts tts;
  final RecordingFeedback feedback;

  LessonStats get stats => container.read(lessonStatsProvider);
}

Future<Harness> pumpActivity(WidgetTester tester, String location) async {
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
  final tts = RecordingTts();
  final feedback = RecordingFeedback();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ttsServiceProvider.overrideWithValue(tts),
      feedbackServiceProvider.overrideWithValue(feedback),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: _router(location),
      ),
    ),
  );
  // The lesson content resolves through a FutureProvider.
  await tester.pumpAndSettle();
  return Harness(container, tts, feedback);
}

/// The sample lesson every demo run plays (`LocalLessonRepository`).
const tapTarget = 'D';
const tapDecoy = 'T';

void main() {
  group('tap activity', () {
    testWidgets('presents the instruction and every letter to choose from', (
      tester,
    ) async {
      await pumpActivity(tester, '/lesson/tap');

      expect(find.textContaining('Toque na letra'), findsOneWidget);
      for (final letter in ['T', 'B', 'D', 'P']) {
        expect(
          find.bySemanticsLabel('Letra $letter'),
          findsOneWidget,
          reason: 'option $letter should be one labelled tile',
        );
      }
    });

    testWidgets('a wrong letter corrects the child and is counted', (
      tester,
    ) async {
      final harness = await pumpActivity(tester, '/lesson/tap');

      await tester.tap(find.bySemanticsLabel('Letra $tapDecoy'));
      await tester.pump();

      expect(find.text('Quase! Tente de novo'), findsOneWidget);
      expect(harness.stats.wrongAnswers, 1);
      expect(harness.stats.correctAnswers, 0);
      expect(harness.tts.spoken, contains('Tente de novo'));
      expect(harness.feedback.played, [FeedbackCue.wrong]);

      // The screen clears the wrong pick so the child can try again.
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Quase! Tente de novo'), findsNothing);
    });

    testWidgets('the right letter celebrates and hands off to the match', (
      tester,
    ) async {
      final harness = await pumpActivity(tester, '/lesson/tap');

      await tester.tap(find.bySemanticsLabel('Letra $tapTarget'));
      await tester.pump();

      expect(find.text('Muito bem! ★'), findsOneWidget);
      expect(harness.stats.correctAnswers, 1);
      expect(harness.feedback.played, [FeedbackCue.correct]);

      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();
      expect(find.text('Ligue as letras iguais'), findsOneWidget);
    });
  });

  group('match activity', () {
    testWidgets('prompts for a capital first, then its lowercase pair', (
      tester,
    ) async {
      await pumpActivity(tester, '/lesson/match');

      expect(find.text('Toque numa letra grande'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Letra D'));
      await tester.pump();
      expect(find.text('Agora toque na letra "d"'), findsOneWidget);
    });

    testWidgets('a mismatched pair is counted and then cleared', (
      tester,
    ) async {
      final harness = await pumpActivity(tester, '/lesson/match');

      await tester.tap(find.bySemanticsLabel('Letra D'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Letra t'));
      await tester.pump();

      expect(harness.stats.wrongAnswers, 1);
      // Still waiting on the right partner for D.
      expect(find.text('Agora toque na letra "d"'), findsOneWidget);

      // Let the screen clear the wrong pick before the test ends.
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('matching all three pairs hands off to the trace', (
      tester,
    ) async {
      final harness = await pumpActivity(tester, '/lesson/match');

      for (final letter in ['D', 'T', 'B']) {
        await tester.tap(find.bySemanticsLabel('Letra $letter'));
        await tester.pump();
        await tester.tap(
          find.bySemanticsLabel('Letra ${letter.toLowerCase()}'),
        );
        await tester.pump();
      }

      expect(harness.stats.correctAnswers, 3);
      expect(find.text('Incrível! ★'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();
      expect(find.textContaining('Trace a letra'), findsWidgets);
    });
  });

  group('trace activity', () {
    testWidgets('"Pronto!" stays shut until the child has actually traced', (
      tester,
    ) async {
      await pumpActivity(tester, '/lesson/trace');

      final done = tester.widget<LeleButton>(
        find.widgetWithText(LeleButton, 'Pronto!'),
      );
      expect(done.enabled, isFalse);
    });

    testWidgets('tracing enables the hand-off, and Limpar undoes it', (
      tester,
    ) async {
      await pumpActivity(tester, '/lesson/trace');

      await tester.drag(
        find.bySemanticsLabel(RegExp('Área de desenho')),
        const Offset(0, 60),
      );
      await tester.pump();

      expect(
        tester
            .widget<LeleButton>(find.widgetWithText(LeleButton, 'Pronto!'))
            .enabled,
        isTrue,
      );

      await tester.tap(find.bySemanticsLabel('Limpar o desenho'));
      await tester.pump();
      expect(
        tester
            .widget<LeleButton>(find.widgetWithText(LeleButton, 'Pronto!'))
            .enabled,
        isFalse,
      );
    });

    testWidgets('a traced letter advances to the listening activity', (
      tester,
    ) async {
      final harness = await pumpActivity(tester, '/lesson/trace');

      await tester.drag(
        find.bySemanticsLabel(RegExp('Área de desenho')),
        const Offset(0, 60),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(LeleButton, 'Pronto!'));
      await tester.pumpAndSettle();

      expect(harness.stats.correctAnswers, 1);
      expect(find.text('Qual palavra você ouviu?'), findsOneWidget);

      // The trace screen speaks the next activity's word 700ms on.
      await tester.pump(const Duration(milliseconds: 800));
      expect(harness.tts.spoken, contains('dado'));
    });
  });

  group('listen activity', () {
    testWidgets('a wrong word asks the child to listen again', (tester) async {
      final harness = await pumpActivity(tester, '/lesson/listen');

      await tester.tap(find.bySemanticsLabel('DENTE'));
      await tester.pump();

      expect(find.text('Escute de novo!'), findsOneWidget);
      expect(harness.stats.wrongAnswers, 1);

      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Escute de novo!'), findsNothing);
    });

    testWidgets('the right word finishes the lesson and opens the reward', (
      tester,
    ) async {
      final harness = await pumpActivity(tester, '/lesson/listen');

      await tester.tap(find.bySemanticsLabel('DADO'));
      await tester.pump();

      expect(find.text('Parabéns! ★'), findsOneWidget);
      expect(harness.stats.correctAnswers, 1);

      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();
      expect(find.text('@reward'), findsOneWidget);
    });
  });

  /// A child who cannot read yet gets the verdict from the sound before the
  /// spoken prompt finishes its first syllable. Two of these activities said
  /// nothing at all on a wrong answer before.
  group('every wrong answer is audible', () {
    testWidgets('tap', (tester) async {
      final harness = await pumpActivity(tester, '/lesson/tap');
      await tester.tap(find.bySemanticsLabel('Letra $tapDecoy'));
      await tester.pump();
      expect(harness.feedback.played, [FeedbackCue.wrong]);
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('match', (tester) async {
      final harness = await pumpActivity(tester, '/lesson/match');
      await tester.tap(find.bySemanticsLabel('Letra D'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Letra t'));
      await tester.pump();
      expect(harness.feedback.played, [FeedbackCue.wrong]);
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('listen', (tester) async {
      final harness = await pumpActivity(tester, '/lesson/listen');
      await tester.tap(find.bySemanticsLabel('DENTE'));
      await tester.pump();
      expect(harness.feedback.played, [FeedbackCue.wrong]);
      await tester.pump(const Duration(milliseconds: 700));
    });
  });

  group('finishing sounds bigger than getting one right', () {
    testWidgets('the last pair of the match activity celebrates', (
      tester,
    ) async {
      final harness = await pumpActivity(tester, '/lesson/match');
      for (final letter in ['D', 'T', 'B']) {
        await tester.tap(find.bySemanticsLabel('Letra $letter'));
        await tester.pump();
        await tester.tap(
          find.bySemanticsLabel('Letra ${letter.toLowerCase()}'),
        );
        await tester.pump();
      }
      expect(harness.feedback.played, [
        FeedbackCue.correct,
        FeedbackCue.correct,
        FeedbackCue.celebrate,
      ]);
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();
    });

    testWidgets('the last word of the lesson celebrates', (tester) async {
      final harness = await pumpActivity(tester, '/lesson/listen');
      await tester.tap(find.bySemanticsLabel('DADO'));
      await tester.pump();
      expect(harness.feedback.played, [FeedbackCue.celebrate]);
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();
    });
  });

  // Locks in the two accessibility defects fixed alongside these tests: a
  // child-facing control that is smaller than a fingertip, or that a screen
  // reader announces as nothing at all.
  group('activity accessibility', () {
    const locations = {
      'tap': '/lesson/tap',
      'match': '/lesson/match',
      'trace': '/lesson/trace',
      'listen': '/lesson/listen',
    };

    for (final entry in locations.entries) {
      testWidgets('${entry.key}: the way out is labelled and big enough', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpActivity(tester, entry.value);

        final close = find.byType(LeleIconButton);
        expect(close, findsOneWidget);

        final size = tester.getSize(close);
        expect(
          size.width,
          greaterThanOrEqualTo(AppSpacing.minTapTarget),
          reason: '${entry.key} close button is under the tap-target floor',
        );
        expect(size.height, greaterThanOrEqualTo(AppSpacing.minTapTarget));

        expect(
          tester.getSemantics(close).label,
          isNotEmpty,
          reason: '${entry.key} close button announces nothing',
        );
        handle.dispose();
      });
    }

    testWidgets('every choice a child can make announces itself', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpActivity(tester, '/lesson/tap');

      for (final letter in ['T', 'B', 'D', 'P']) {
        final tile = find.bySemanticsLabel('Letra $letter');
        expect(tile, findsOneWidget);
        expect(tester.getSemantics(tile).flagsCollection.isButton, isTrue);
      }
      handle.dispose();
    });
  });
}
