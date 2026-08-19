import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/features/lesson/application/lesson_stats_controller.dart';

ProviderContainer makeContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('LessonStats', () {
    test('scores a perfect run at 100', () {
      const stats = LessonStats(correctAnswers: 4, wrongAnswers: 0);
      expect(stats.attempts, 4);
      expect(stats.score, 100);
    });

    test('scores by ratio of correct answers', () {
      const stats = LessonStats(correctAnswers: 3, wrongAnswers: 1);
      expect(stats.attempts, 4);
      expect(stats.score, 75);
    });

    test('an empty run scores 0 without dividing by zero', () {
      const stats = LessonStats();
      expect(stats.attempts, 0);
      expect(stats.score, 0);
    });

    test('duration is 0 before the lesson starts', () {
      const stats = LessonStats();
      expect(stats.durationSeconds(DateTime.now()), 0);
    });

    test('duration measures from the start instant', () {
      final start = DateTime(2026, 8, 19, 10, 0, 0);
      final stats = LessonStats(startedAt: start);
      expect(stats.durationSeconds(start.add(const Duration(minutes: 15))),
          15 * 60);
    });

    test('duration never exceeds a day (backend validation bound)', () {
      final start = DateTime(2026, 8, 1);
      final stats = LessonStats(startedAt: start);
      expect(
        stats.durationSeconds(start.add(const Duration(days: 3))),
        24 * 3600,
      );
    });
  });

  group('LessonStatsController', () {
    test('accumulates answers across activities', () {
      final container = makeContainer();
      final controller = container.read(lessonStatsProvider.notifier);
      controller.start();
      controller.recordCorrect();
      controller.recordWrong();
      controller.recordCorrect();

      final stats = container.read(lessonStatsProvider);
      expect(stats.correctAnswers, 2);
      expect(stats.wrongAnswers, 1);
      expect(stats.attempts, 3);
      expect(stats.score, 67);
      expect(stats.startedAt, isNotNull);
    });

    test('start resets stats for a new lesson run', () {
      final container = makeContainer();
      final controller = container.read(lessonStatsProvider.notifier);
      controller.start();
      controller.recordWrong();
      controller.start();

      final stats = container.read(lessonStatsProvider);
      expect(stats.correctAnswers, 0);
      expect(stats.wrongAnswers, 0);
    });
  });
}
