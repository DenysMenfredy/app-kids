import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/learning_week.dart';

abstract interface class WeeklyLearningRepository {
  Future<LearningWeek> load(String childId);
}

class CallableWeeklyLearningRepository implements WeeklyLearningRepository {
  CallableWeeklyLearningRepository(this._functions);
  final FirebaseFunctions _functions;
  @override
  Future<LearningWeek> load(String childId) async {
    final result = await _functions
        .httpsCallable('getWeeklyLearningSummary')
        .call<Object?>({'childId': childId});
    return learningWeekFromMap(result.data);
  }
}

LearningWeek learningWeekFromMap(Object? raw) {
  if (raw is! Map ||
      raw['schemaVersion'] != 1 ||
      raw['today'] is! String ||
      raw['days'] is! List ||
      (raw['days'] as List).length != 7) {
    throw const FormatException('Invalid learning summary');
  }
  int count(Object? value) {
    if (value is! int || value < 0) {
      throw const FormatException('Invalid learning count');
    }
    return value;
  }

  final dates = <String>{};
  final days = <LearningDay>[];
  for (final item in raw['days'] as List) {
    if (item is! Map ||
        item['localDate'] is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(item['localDate'] as String) ||
        !dates.add(item['localDate'] as String)) {
      throw const FormatException('Invalid learning day');
    }
    final attempts = count(item['attempts']);
    final correct = count(item['correctAnswers']);
    if (correct > attempts) {
      throw const FormatException('Invalid learning accuracy');
    }
    days.add(
      LearningDay(
        localDate: item['localDate'] as String,
        activeSeconds: count(item['activeSeconds']),
        lessonsCompleted: count(item['lessonsCompleted']),
        sessionsCompleted: count(item['sessionsCompleted']),
        attempts: attempts,
        correctAnswers: correct,
      ),
    );
  }
  if (!dates.contains(raw['today'])) {
    throw const FormatException('Invalid learning week');
  }
  return LearningWeek(
    today: raw['today'] as String,
    days: List.unmodifiable(days),
    dailyGoalLessons: count(raw['dailyGoalLessons']),
    refreshAfterMilliseconds: raw['refreshAfterMilliseconds'] as int?,
  );
}

final weeklyLearningRepositoryProvider = Provider<WeeklyLearningRepository>(
  (ref) => CallableWeeklyLearningRepository(ref.watch(functionsProvider)),
);
