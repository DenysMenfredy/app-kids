import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Accumulates answer stats across the four activities of a lesson run so
/// the backend's completeLesson callable receives real data.
class LessonStats extends Equatable {
  const LessonStats({
    this.startedAt,
    this.correctAnswers = 0,
    this.wrongAnswers = 0,
  });

  final DateTime? startedAt;
  final int correctAnswers;
  final int wrongAnswers;

  int get attempts => correctAnswers + wrongAnswers;

  /// 0–100; a run with no recorded answers scores 0.
  int get score =>
      attempts == 0 ? 0 : (100 * correctAnswers / attempts).round();

  int durationSeconds(DateTime now) => startedAt == null
      ? 0
      : now.difference(startedAt!).inSeconds.clamp(0, 24 * 3600);

  LessonStats copyWith({
    DateTime? startedAt,
    int? correctAnswers,
    int? wrongAnswers,
  }) {
    return LessonStats(
      startedAt: startedAt ?? this.startedAt,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      wrongAnswers: wrongAnswers ?? this.wrongAnswers,
    );
  }

  @override
  List<Object?> get props => [startedAt, correctAnswers, wrongAnswers];
}

class LessonStatsController extends Notifier<LessonStats> {
  @override
  LessonStats build() => const LessonStats();

  void start() => state = LessonStats(startedAt: DateTime.now());

  void recordCorrect() =>
      state = state.copyWith(correctAnswers: state.correctAnswers + 1);

  void recordWrong() =>
      state = state.copyWith(wrongAnswers: state.wrongAnswers + 1);
}

final lessonStatsProvider =
    NotifierProvider<LessonStatsController, LessonStats>(
      LessonStatsController.new,
    );
