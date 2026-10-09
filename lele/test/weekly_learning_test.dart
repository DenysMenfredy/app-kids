import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/features/dashboard/application/weekly_learning_provider.dart';
import 'package:lele/features/dashboard/data/weekly_learning_repository.dart';
import 'package:lele/features/dashboard/domain/learning_week.dart';
import 'package:lele/features/dashboard/presentation/weekly_learning_card.dart';

void main() {
  final empty = LearningWeek.empty(DateTime(2026, 10, 9));
  test('accuracy uses total answers and empty data never invents practice', () {
    expect(empty.activeSeconds, 0);
    expect(empty.accuracy, isNull);
    final week = LearningWeek(
      today: empty.today,
      days: [
        const LearningDay(
          localDate: '2026-10-08',
          attempts: 1,
          correctAnswers: 1,
        ),
        const LearningDay(
          localDate: '2026-10-09',
          attempts: 9,
          correctAnswers: 0,
        ),
      ],
    );
    expect(week.accuracy, 10);
  });
  test('rejects duplicate dates and contradictory server counts', () {
    final raw = {
      'schemaVersion': 1,
      'today': empty.today,
      'dailyGoalLessons': 1,
      'days': [
        for (final day in empty.days)
          {
            'localDate': day.localDate,
            'activeSeconds': 0,
            'lessonsCompleted': 0,
            'sessionsCompleted': 0,
            'attempts': 0,
            'correctAnswers': 0,
          },
      ],
    };
    expect(learningWeekFromMap(raw).sessionsCompleted, 0);
    (raw['days']! as List<Map<String, Object>>)[0]['correctAnswers'] = 2;
    expect(() => learningWeekFromMap(raw), throwsFormatException);
    (raw['days']! as List<Map<String, Object>>)[0]['correctAnswers'] = 0;
    (raw['days']! as List<Map<String, Object>>)[1]['localDate'] =
        empty.days[0].localDate;
    expect(() => learningWeekFromMap(raw), throwsFormatException);
  });

  Future<void> pump(WidgetTester tester, AsyncValue<LearningWeek> state) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [weeklyLearningProvider.overrideWithValue(state)],
          child: const MaterialApp(home: Scaffold(body: WeeklyLearningCard())),
        ),
      );
  testWidgets('shows empty, loading, and actionable error states', (
    tester,
  ) async {
    await pump(tester, AsyncData(empty));
    expect(
      find.text('Seu resumo aparece após a próxima prática concluída.'),
      findsOneWidget,
    );
    expect(find.textContaining('68 min'), findsNothing);
    await pump(tester, const AsyncLoading());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await pump(tester, AsyncError(StateError('offline'), StackTrace.empty));
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
  testWidgets('renders actual totals and weights accuracy by attempts', (
    tester,
  ) async {
    final week = LearningWeek(
      today: empty.today,
      days: [
        for (final day in empty.days)
          day.localDate == empty.today
              ? LearningDay(
                  localDate: day.localDate,
                  activeSeconds: 125,
                  lessonsCompleted: 2,
                  sessionsCompleted: 3,
                  attempts: 10,
                  correctAnswers: 7,
                )
              : day,
      ],
    );
    await pump(tester, AsyncData(week));
    expect(find.text('2 lições novas · 2 min de prática'), findsOneWidget);
    expect(find.text('70% de acertos nas atividades'), findsOneWidget);
    expect(find.text('Hoje: 2/1 lição nova'), findsOneWidget);
  });
}
