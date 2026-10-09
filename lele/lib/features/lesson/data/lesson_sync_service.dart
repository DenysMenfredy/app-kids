import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/lesson_reward.dart';

/// Reports lesson sessions and activity responses through trusted callables.
/// Scores and rewards are calculated from the server-owned session evidence.
abstract interface class LessonSyncService {
  Future<void> sessionLifecycle(String lessonId, String childId, String action);
  Future<void> lessonStarted(String lessonId, String childId);

  Future<void> activityAttempt(
    String lessonId,
    String childId,
    String activityId,
    Map<String, Object?> response,
  );

  /// Returns what the backend granted, or null when it couldn't be reached.
  Future<LessonReward?> lessonCompleted(String lessonId, String childId);
}

class NoopLessonSyncService implements LessonSyncService {
  const NoopLessonSyncService();

  @override
  Future<void> sessionLifecycle(
    String lessonId,
    String childId,
    String action,
  ) async {}

  @override
  Future<void> lessonStarted(String lessonId, String childId) async {}

  @override
  Future<void> activityAttempt(
    String lessonId,
    String childId,
    String activityId,
    Map<String, Object?> response,
  ) async {}

  @override
  Future<LessonReward?> lessonCompleted(
    String lessonId,
    String childId,
  ) async => LessonReward.demo;
}

class CallableLessonSyncService implements LessonSyncService {
  CallableLessonSyncService(this._functions);

  final FirebaseFunctions _functions;
  final Map<String, Future<String?>> _sessions = {};
  final Map<String, Future<void>> _pendingAttempts = {};
  final Set<String> _failedAttemptLessons = {};
  int _requestCounter = 0;
  final Map<String, int> _lifecycleSequences = {};

  String _key(String lessonId, String childId) => '$childId:$lessonId';

  @override
  Future<void> lessonStarted(String lessonId, String childId) {
    final key = _key(lessonId, childId);
    _pendingAttempts[key] = Future<void>.value();
    _failedAttemptLessons.remove(key);
    _lifecycleSequences[key] = 0;
    final session =
        _call('startLessonSession', {
          'lessonId': lessonId,
          'childId': childId,
        }).then((data) {
          if (data is Map && data['sessionId'] is String) {
            return data['sessionId'] as String;
          }
          return null;
        });
    _sessions[key] = session;
    return session.then<void>((_) {});
  }

  @override
  Future<void> activityAttempt(
    String lessonId,
    String childId,
    String activityId,
    Map<String, Object?> response,
  ) async {
    final key = _key(lessonId, childId);
    final previous = _pendingAttempts[key] ?? Future<void>.value();
    final session = _sessions[key];
    final queued = previous.then((_) async {
      try {
        final sessionId = await session;
        if (sessionId == null) throw StateError('Lesson session did not start');
        _requestCounter++;
        final requestId =
            '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_$_requestCounter';
        final result = await _call('submitActivityAttempt', {
          'childId': childId,
          'sessionId': sessionId,
          'activityId': activityId,
          'requestId': requestId,
          'response': response,
        }, retry: true);
        if (result is! Map || result['ok'] != true) {
          throw StateError('Activity attempt was not accepted');
        }
      } catch (_) {
        if (identical(_sessions[key], session)) _failedAttemptLessons.add(key);
      }
    });
    _pendingAttempts[key] = queued;
    await queued;
  }

  @override
  Future<LessonReward?> lessonCompleted(String lessonId, String childId) async {
    final key = _key(lessonId, childId);
    final session = _sessions[key];
    await (_pendingAttempts[key] ?? Future<void>.value());
    final sessionId = await session;
    if (sessionId == null || _failedAttemptLessons.contains(key)) {
      return null;
    }
    final data = await _call('completeLesson', {
      'lessonId': lessonId,
      'childId': childId,
      'sessionId': sessionId,
    }, retry: true);
    if (data is! Map) return null;
    return LessonReward.fromMap(
      data.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  @override
  Future<void> sessionLifecycle(
    String lessonId,
    String childId,
    String action,
  ) {
    final key = _key(lessonId, childId);
    final session = _sessions[key];
    final sequence = (_lifecycleSequences[key] ?? 0) + 1;
    _lifecycleSequences[key] = sequence;
    final previous = _pendingAttempts[key] ?? Future<void>.value();
    final queued = previous.then((_) async {
      final sessionId = await session;
      if (sessionId == null) return;
      await _call('updateLessonSession', {
        'childId': childId,
        'sessionId': sessionId,
        'action': action,
        'sequence': sequence,
      }, retry: true);
    });
    _pendingAttempts[key] = queued;
    return queued;
  }

  Future<Object?> _call(
    String callable,
    Map<String, dynamic> data, {
    bool retry = false,
  }) async {
    for (var attempt = 0; attempt < (retry ? 3 : 1); attempt++) {
      try {
        final result = await _functions
            .httpsCallable(callable)
            .call<dynamic>(data);
        return result.data;
      } on FirebaseFunctionsException catch (error) {
        if (!retry ||
            ![
              'unavailable',
              'deadline-exceeded',
              'internal',
            ].contains(error.code) ||
            attempt == 2) {
          debugPrint('lesson sync failed ($callable): ${error.code}');
          return null;
        }
        await Future<void>.delayed(Duration(milliseconds: 200 * (attempt + 1)));
      } catch (_) {
        debugPrint('lesson sync failed ($callable)');
        return null;
      }
    }
    return null;
  }
}

final lessonSyncServiceProvider = Provider<LessonSyncService>((ref) {
  if (AppConfig.useFirebase) {
    return CallableLessonSyncService(ref.watch(functionsProvider));
  }
  return const NoopLessonSyncService();
});
