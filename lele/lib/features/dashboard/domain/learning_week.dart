class LearningDay {
  const LearningDay({
    required this.localDate,
    this.activeSeconds = 0,
    this.lessonsCompleted = 0,
    this.sessionsCompleted = 0,
    this.attempts = 0,
    this.correctAnswers = 0,
  });
  final String localDate;
  final int activeSeconds;
  final int lessonsCompleted;
  final int sessionsCompleted;
  final int attempts;
  final int correctAnswers;
}

class LearningWeek {
  const LearningWeek({
    required this.today,
    required this.days,
    this.dailyGoalLessons = 1,
    this.refreshAfterMilliseconds,
  });
  final String today;
  final List<LearningDay> days;
  final int dailyGoalLessons;
  final int? refreshAfterMilliseconds;
  int get activeSeconds => days.fold(0, (sum, day) => sum + day.activeSeconds);
  int get lessonsCompleted =>
      days.fold(0, (sum, day) => sum + day.lessonsCompleted);
  int get sessionsCompleted =>
      days.fold(0, (sum, day) => sum + day.sessionsCompleted);
  int? get accuracy {
    final attempts = days.fold<int>(0, (sum, day) => sum + day.attempts);
    final correct = days.fold<int>(0, (sum, day) => sum + day.correctAnswers);
    return attempts == 0 ? null : (100 * correct / attempts).round();
  }

  int get todayLessons => days
      .where((day) => day.localDate == today)
      .fold(0, (sum, day) => sum + day.lessonsCompleted);
  factory LearningWeek.empty(DateTime now) {
    final day = DateTime.utc(now.year, now.month, now.day);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    return LearningWeek(
      today: day.toIso8601String().substring(0, 10),
      days: List.unmodifiable(
        List.generate(
          7,
          (index) => LearningDay(
            localDate: monday
                .add(Duration(days: index))
                .toIso8601String()
                .substring(0, 10),
          ),
        ),
      ),
    );
  }
}
