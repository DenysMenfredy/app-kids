import 'package:cloud_functions/cloud_functions.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';

/// What the backend granted for a finished lesson (ADR 0003). `awarded` is
/// false when the lesson had already been completed — replaying it refreshes
/// the stats but grants nothing, so the reward screen shows no deltas.
class LessonReward extends Equatable {
  const LessonReward({
    required this.awarded,
    required this.xpEarned,
    required this.coinsEarned,
    required this.xp,
    required this.coins,
    required this.streak,
  });

  final bool awarded;
  final int xpEarned;
  final int coinsEarned;
  final int xp;
  final int coins;
  final int streak;

  /// Demo-mode rewards, matching the backend's constants.
  static const demo = LessonReward(
    awarded: true,
    xpEarned: 50,
    coinsEarned: 10,
    xp: 0,
    coins: 0,
    streak: 0,
  );

  factory LessonReward.fromMap(Map<String, dynamic> map) {
    int intOf(String key) => (map[key] as num?)?.toInt() ?? 0;
    return LessonReward(
      awarded: map['awarded'] == true,
      xpEarned: intOf('xpEarned'),
      coinsEarned: intOf('coinsEarned'),
      xp: intOf('xp'),
      coins: intOf('coins'),
      streak: intOf('streak'),
    );
  }

  @override
  List<Object?> get props => [awarded, xpEarned, coinsEarned, xp, coins, streak];
}

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
  }) async =>
      LessonReward.demo;
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
      final result = await _functions.httpsCallable(callable).call<dynamic>(data);
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

/// The reward from the lesson just finished, handed to the reward screen.
class LastLessonReward extends Notifier<LessonReward?> {
  @override
  LessonReward? build() => null;

  void set(LessonReward? reward) => state = reward;
}

final lastLessonRewardProvider =
    NotifierProvider<LastLessonReward, LessonReward?>(LastLessonReward.new);
