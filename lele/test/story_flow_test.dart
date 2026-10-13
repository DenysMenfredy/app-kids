import 'dart:convert';
import 'dart:io';

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
import 'package:lele/core/widgets/lele_button.dart';
import 'package:lele/features/learning/application/journey_provider.dart';
import 'package:lele/features/lesson/application/lesson_controller.dart';
import 'package:lele/features/lesson/application/lesson_session_controller.dart';
import 'package:lele/features/lesson/data/lesson_repository.dart';
import 'package:lele/features/lesson/data/lesson_sync_service.dart';
import 'package:lele/features/lesson/domain/lesson.dart';
import 'package:lele/features/lesson/domain/lesson_recovery.dart';
import 'package:lele/features/lesson/domain/lesson_reward.dart';
import 'package:lele/features/lesson/domain/story.dart';
import 'package:lele/features/lesson/presentation/activities/story_activity_screen.dart';
import 'package:lele/features/session/application/child_provider.dart';
import 'package:lele/features/session/application/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_fonts.dart';

const _story = StoryActivity(
  id: 'activity_032_story',
  storyId: 'story_001',
  title: 'A Lua',
  contentVersion: 1,
  pages: [
    StoryPage(id: 'p1', text: 'A lua apareceu no céu.', illustration: 'moon'),
    StoryPage(id: 'p2', text: 'O sapo saiu do lago.', illustration: 'frog'),
  ],
  questions: [
    StoryQuestion(
      id: 'q1',
      prompt: 'Quem saiu do lago?',
      options: ['O sapo', 'O gato'],
      answer: 'O sapo',
    ),
    StoryQuestion(
      id: 'q2',
      prompt: 'O que apareceu no céu?',
      options: ['A lua', 'Uma bola'],
      answer: 'A lua',
    ),
  ],
);

class _Tts extends TtsService {
  final spoken = <String>[];
  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

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

class _Sync extends NoopLessonSyncService {
  _Sync({this.confirm = true});
  bool confirm;
  final attempts = <Map<String, Object?>>[];
  int completions = 0;
  @override
  Future<void> activityAttempt(
    String lessonId,
    String childId,
    String activityId,
    Map<String, Object?> response,
  ) async {
    expect(lessonId, 'lesson_032');
    expect(childId, 'child-test');
    expect(activityId, _story.id);
    attempts.add(response);
  }

  @override
  Future<LessonReward?> lessonCompleted(String lessonId, String childId) async {
    completions++;
    return confirm ? LessonReward.demo : null;
  }
}

List<Map<String, dynamic>> _seed(String path) =>
    (jsonDecode(File('../backend/seed/$path').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

void main() {
  setUpAll(loadAppFonts);
  test('all six published stories parse and add a final lesson step', () {
    final lessons = _seed('lessons/lessons.json');
    final activities = [
      ..._seed('activities/activities.json'),
      ..._seed('activities/stories.json'),
    ];
    for (final story in _seed('stories/stories.json')) {
      final id = story['lessonId'] as String;
      final content = lessonContentFromMaps(
        id,
        lessons.firstWhere((lesson) => lesson['id'] == id),
        activities.where((activity) => activity['lessonId'] == id).toList(),
        story: story,
      );
      expect(content.story!.pages, isNotEmpty);
      expect(content.story!.questions, hasLength(2));
      expect(content.activityTypes, hasLength(5));
      expect(content.activityTypes.last, ActivityType.story);
    }
    const flow = LessonFlow(hasStory: true);
    expect(flow.nextRoute(ActivityType.listen), AppRoutes.activityStory);
    expect(flow.nextRoute(ActivityType.story), AppRoutes.reward);
    expect(const LessonFlow().nextRoute(ActivityType.listen), AppRoutes.reward);
  });
  test(
    'rejects missing, malformed, duplicate and unversioned story payloads',
    () {
      final raw = _seed('stories/stories.json').first;
      const activity = {'id': 'activity_032_story', 'storyId': 'story_001'};
      expect(
        () => storyActivityFromMap('lesson_032', activity, null),
        throwsFormatException,
      );
      expect(
        () => storyActivityFromMap('lesson_032', activity, {
          ...raw,
          'schemaVersion': 99,
        }),
        throwsFormatException,
      );
      expect(
        () => storyActivityFromMap('lesson_032', activity, {
          ...raw,
          'questions': [],
        }),
        throwsFormatException,
      );
      expect(
        () => storyActivityFromMap('wrong-lesson', activity, raw),
        throwsFormatException,
      );
      final questions = (raw['questions'] as List).cast<Map<String, dynamic>>();
      expect(
        () => storyActivityFromMap('lesson_032', activity, {
          ...raw,
          'questions': [questions.first, questions.first],
        }),
        throwsFormatException,
      );
      expect(
        () => storyActivityFromMap('lesson_032', activity, {
          ...raw,
          'questions': [
            {...questions.first, 'answer': 'invented'},
          ],
        }),
        throwsFormatException,
      );
    },
  );
  testWidgets('recovered story opens the first unconfirmed question', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final scope = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        sessionStorageScopeProvider.overrideWithValue('test-parent'),
        ttsServiceProvider.overrideWithValue(_Tts()),
        feedbackServiceProvider.overrideWithValue(_Feedback()),
      ],
    );
    addTearDown(scope.dispose);
    scope
        .read(lessonRunProvider.notifier)
        .set(
          const LessonRecovery(
            lessonId: 'lesson_032',
            nextActivityIndex: 4,
            completedItems: {
              'activity_032_story': {'q1'},
            },
            correctAnswers: 5,
            wrongAnswers: 1,
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const StoryPlayer(story: _story),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pergunta 2 de 2'), findsOneWidget);
    expect(find.text('O que apareceu no céu?'), findsOneWidget);
    expect(find.text('Quem saiu do lago?'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final (size, confirmed) in const [
    (Size(390, 844), true),
    (Size(320, 568), true),
    (Size(390, 844), false),
  ]) {
    testWidgets(
      'reads, narrates and retries on $size (confirmed: $confirmed)',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final sync = _Sync(confirm: confirmed);
        final tts = _Tts();
        final feedback = _Feedback();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            sessionStorageScopeProvider.overrideWithValue('test-parent'),
            activeChildIdProvider.overrideWithValue('child-test'),
            currentLessonIdProvider.overrideWithValue('lesson_032'),
            lessonSyncServiceProvider.overrideWithValue(sync),
            ttsServiceProvider.overrideWithValue(tts),
            feedbackServiceProvider.overrideWithValue(feedback),
          ],
        );
        addTearDown(container.dispose);
        expect(await container.read(lessonSessionProvider).start(), isTrue);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const StoryPlayer(story: _story),
            ),
            GoRoute(
              path: '/reward',
              name: AppRoutes.reward,
              builder: (_, _) => const Scaffold(body: Text('Reward confirmed')),
            ),
            GoRoute(
              path: '/child',
              name: AppRoutes.childHome,
              builder: (_, _) => const Scaffold(),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Página 1 de 2'), findsOneWidget);
        await tester.tap(find.text('Ouvir a página'));
        await tester.pump();
        expect(tts.spoken, ['A lua apareceu no céu.']);
        await tester.tap(find.text('Próxima página'));
        await tester.pumpAndSettle();
        expect(find.text('Página 2 de 2'), findsOneWidget);
        await tester.tap(find.text('Página anterior'));
        await tester.pumpAndSettle();
        expect(find.text('Página 1 de 2'), findsOneWidget);
        await tester.tap(find.text('Próxima página'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Responder perguntas'));
        await tester.pumpAndSettle();
        expect(find.text('Pergunta 1 de 2'), findsOneWidget);
        expect(
          tester.widget<LeleButton>(find.byType(LeleButton)).enabled,
          isFalse,
        );
        await tester.tap(find.text('O gato'));
        await tester.pump();
        expect(find.text('Vamos tentar de novo!'), findsOneWidget);
        expect(sync.completions, 0);
        await tester.tap(find.text('O sapo'));
        await tester.pumpAndSettle();
        expect(find.text('Muito bem! ★'), findsOneWidget);
        await tester.tap(find.text('Próxima pergunta'));
        await tester.pumpAndSettle();
        expect(find.text('Pergunta 2 de 2'), findsOneWidget);
        await tester.tap(find.text('A lua'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Concluir história'));
        await tester.pumpAndSettle();
        expect(
          find.text('Reward confirmed'),
          confirmed ? findsOneWidget : findsNothing,
        );
        if (!confirmed) {
          expect(find.text('Tentar salvar novamente'), findsOneWidget);
        }
        expect(sync.completions, 1);
        expect(sync.attempts, [
          {'questionId': 'q1', 'selectedLabel': 'O gato'},
          {'questionId': 'q1', 'selectedLabel': 'O sapo'},
          {'questionId': 'q2', 'selectedLabel': 'A lua'},
        ]);
        expect(feedback.cues, [
          FeedbackCue.wrong,
          FeedbackCue.correct,
          FeedbackCue.correct,
          if (confirmed) FeedbackCue.celebrate,
        ]);
        expect(tester.takeException(), isNull);
        if (!confirmed) {
          sync.confirm = true;
          await tester.tap(find.text('Tentar salvar novamente'));
          await tester.pumpAndSettle();
          expect(find.text('Reward confirmed'), findsOneWidget);
          expect(sync.completions, 2);
          expect(sync.attempts, hasLength(3));
          expect(feedback.cues.last, FeedbackCue.celebrate);
        }
      },
    );
  }
}
