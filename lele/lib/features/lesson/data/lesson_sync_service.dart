import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/lesson_reward.dart';

/// Reports lesson lifecycle to the backend through the validated callables
/// (`updateProgress`, `completeLesson`). Calls are fire-safe: a lost call
/// never blocks the child's flow, and the backend only grants a reward for a
/// first-time completion, so retries can't mint XP (spec §20).
abstract interface class LessonSyncService {
  Future<void> lessonStarted(String lessonId);

  /// Returns what the backend granted, or null when it couldn't be reached.
  Future<LessonReward?> lessonCompleted(
    String lessonId, {
    int durationSeconds,
    int score,
    int attempts,
    int correctAnswers,
    int wrongAnswers,
  });
}

class NoopLessonSyncService implements LessonSyncService {
  const NoopLessonSyncService();

  @override
  Future<void> lessonStarted(String lessonId) async {}

  @override
  Future<LessonReward?> lessonCompleted(
    String lessonId, {
    int durationSeconds = 0,
    int score = 0,
    int attempts = 0,
    int correctAnswers = 0,
    int wrongAnswers = 0,
  }) async => LessonReward.demo;
}

class CallableLessonSyncService implements LessonSyncService {
  CallableLessonSyncService(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<void> lessonStarted(String lessonId) async {
    await _call('updateProgress', {
      'lessonId': lessonId,
      'childId': AppConfig.primaryChildId,
      'status': 'in_progress',
    });
  }

  @override
  Future<LessonReward?> lessonCompleted(
    String lessonId, {
    int durationSeconds = 0,
    int score = 0,
    int attempts = 0,
    int correctAnswers = 0,
    int wrongAnswers = 0,
  }) async {
    final data = await _call('completeLesson', {
      'lessonId': lessonId,
      'childId': AppConfig.primaryChildId,
      'durationSeconds': durationSeconds,
      'score': score,
      'attempts': attempts,
      'correctAnswers': correctAnswers,
      'wrongAnswers': wrongAnswers,
    });
    if (data is! Map) return null;
    return LessonReward.fromMap(
      data.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<Object?> _call(String callable, Map<String, dynamic> data) async {
    try {
      final result = await _functions
          .httpsCallable(callable)
          .call<dynamic>(data);
      return result.data;
    } catch (error) {
      debugPrint('lesson sync failed ($callable): $error');
      return null;
    }
  }
}

final lessonSyncServiceProvider = Provider<LessonSyncService>((ref) {
  if (AppConfig.useFirebase) {
    return CallableLessonSyncService(ref.watch(functionsProvider));
  }
  return const NoopLessonSyncService();
});
