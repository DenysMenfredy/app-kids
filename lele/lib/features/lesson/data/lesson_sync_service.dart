import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';

/// Reports lesson lifecycle to the backend through the validated callables
/// (`updateProgress`, `completeLesson`). Calls are fire-safe: a lost call
/// never blocks the child's flow, and the backend's keyed writes make
/// retried completions idempotent (spec §20).
abstract interface class LessonSyncService {
  Future<void> lessonStarted(String lessonId);

  Future<void> lessonCompleted(
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
  Future<void> lessonCompleted(
    String lessonId, {
    int durationSeconds = 0,
    int score = 0,
    int attempts = 0,
    int correctAnswers = 0,
    int wrongAnswers = 0,
  }) async {}
}

class CallableLessonSyncService implements LessonSyncService {
  CallableLessonSyncService(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<void> lessonStarted(String lessonId) {
    return _tolerant('updateProgress', {
      'lessonId': lessonId,
      'childId': AppConfig.primaryChildId,
      'status': 'in_progress',
    });
  }

  @override
  Future<void> lessonCompleted(
    String lessonId, {
    int durationSeconds = 0,
    int score = 0,
    int attempts = 0,
    int correctAnswers = 0,
    int wrongAnswers = 0,
  }) {
    return _tolerant('completeLesson', {
      'lessonId': lessonId,
      'childId': AppConfig.primaryChildId,
      'durationSeconds': durationSeconds,
      'score': score,
      'attempts': attempts,
      'correctAnswers': correctAnswers,
      'wrongAnswers': wrongAnswers,
    });
  }

  Future<void> _tolerant(String callable, Map<String, dynamic> data) async {
    try {
      await _functions.httpsCallable(callable).call<dynamic>(data);
    } catch (error) {
      debugPrint('lesson sync failed ($callable): $error');
    }
  }
}

final lessonSyncServiceProvider = Provider<LessonSyncService>((ref) {
  if (AppConfig.useFirebase) {
    return CallableLessonSyncService(ref.watch(functionsProvider));
  }
  return const NoopLessonSyncService();
});
