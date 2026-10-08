import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../learning/application/journey_provider.dart';
import '../../session/application/child_provider.dart';
import '../../session/application/demo_progress_controller.dart';
import '../../session/application/session_controller.dart';
import '../data/lesson_sync_service.dart';
import '../domain/lesson_reward.dart';
import 'lesson_reward_provider.dart';
import 'lesson_stats_controller.dart';

/// One run through a lesson, from "Começar!" to the reward screen.
///
/// The steps either side of the child's answers — resetting the stats,
/// telling the backend, advancing the demo journey, publishing the reward —
/// were spread across the lesson intro and the last activity screen, which
/// meant a widget had to know the order to do them in. They are the lesson
/// session, so they live here.
class LessonSessionController {
  LessonSessionController(this._ref);

  final Ref _ref;
  String? _activeChildId;
  String? _activeOwnerScope;

  /// How long to wait for the backend before the child moves on regardless.
  static const _rewardTimeout = Duration(seconds: 3);

  /// Begins a run: clears the stats and reports the start.
  void start() {
    final childId = _ref.read(activeChildIdProvider);
    _activeChildId = childId;
    _activeOwnerScope = _ref.read(sessionStorageScopeProvider);
    _ref.read(lessonStatsProvider.notifier).start();
    unawaited(
      _ref
          .read(lessonSyncServiceProvider)
          .lessonStarted(_ref.read(currentLessonIdProvider), childId),
    );
  }

  /// Queues an answer with the backend; the server determines correctness.
  void recordAttempt(String activityId, Map<String, Object?> response) {
    if (_activeOwnerScope != _ref.read(sessionStorageScopeProvider)) return;
    final childId = _activeChildId ?? _ref.read(activeChildIdProvider);
    if (childId == null) return;
    unawaited(
      _ref
          .read(lessonSyncServiceProvider)
          .activityAttempt(
            _ref.read(currentLessonIdProvider),
            childId,
            activityId,
            response,
          ),
    );
  }

  /// Reports the finished lesson and returns what the backend granted.
  ///
  /// Called the moment the child answers the last question rather than on
  /// the reward screen: the backend decides the reward (ADR 0003), and the
  /// celebration animation is what covers the round trip. Resolves to null
  /// when the backend is unreachable or slow, which the reward screen shows
  /// as a completed lesson with no deltas.
  Future<LessonReward?> complete() {
    if (_activeOwnerScope != _ref.read(sessionStorageScopeProvider)) {
      return Future.value(null);
    }
    final finishedLessonId = _ref.read(currentLessonIdProvider);
    final childId = _activeChildId ?? _ref.read(activeChildIdProvider);
    if (childId == null) return Future.value(null);
    final reward = _ref
        .read(lessonSyncServiceProvider)
        .lessonCompleted(finishedLessonId, childId)
        .timeout(_rewardTimeout, onTimeout: () => null);

    // Demo mode only — the backend owns both of these once it is on.
    _ref.read(demoProgressProvider.notifier).completeLesson();
    _ref.read(demoLessonProvider.notifier).completed(finishedLessonId);

    return reward;
  }

  /// Hands the reward to the screen that celebrates it.
  void publishReward(LessonReward? reward) =>
      _ref.read(lastLessonRewardProvider.notifier).set(reward);
}

final lessonSessionProvider = Provider<LessonSessionController>(
  LessonSessionController.new,
);
