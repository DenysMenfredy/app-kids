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
  String? _activeLessonId;
  Timer? _presenceTimer;
  bool _foreground = true;
  Future<LessonReward?>? _completion;

  /// How long to wait for the backend before the child moves on regardless.
  static const _rewardTimeout = Duration(seconds: 3);

  /// Begins a run: clears the stats and reports the start.
  void start() {
    leave();
    _completion = null;
    final childId = _ref.read(activeChildIdProvider);
    _activeChildId = childId;
    _activeOwnerScope = _ref.read(sessionStorageScopeProvider);
    _activeLessonId = _ref.read(currentLessonIdProvider);
    _ref.read(lessonStatsProvider.notifier).start();
    unawaited(
      _ref
          .read(lessonSyncServiceProvider)
          .lessonStarted(_activeLessonId!, childId),
    );
    _presenceTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_foreground) _lifecycle('heartbeat');
    });
  }

  void _lifecycle(String action) {
    if (_activeLessonId == null ||
        _activeChildId == null ||
        _activeOwnerScope != _ref.read(sessionStorageScopeProvider)) {
      return;
    }
    unawaited(
      _ref
          .read(lessonSyncServiceProvider)
          .sessionLifecycle(_activeLessonId!, _activeChildId!, action),
    );
  }

  void setForeground(bool foreground) {
    if (_foreground == foreground) return;
    _foreground = foreground;
    _lifecycle(foreground ? 'resume' : 'pause');
  }

  void leave() {
    _presenceTimer?.cancel();
    _lifecycle('abandon');
    _activeLessonId = null;
    _activeChildId = null;
    _activeOwnerScope = null;
  }

  void dispose() => _presenceTimer?.cancel();

  /// Queues an answer with the backend; the server determines correctness.
  void recordAttempt(String activityId, Map<String, Object?> response) {
    if (_activeOwnerScope != _ref.read(sessionStorageScopeProvider)) return;
    final childId = _activeChildId;
    final lessonId = _activeLessonId;
    if (childId == null || lessonId == null) return;
    unawaited(
      _ref
          .read(lessonSyncServiceProvider)
          .activityAttempt(
            lessonId,
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
    if (_completion != null) return _completion!;
    _presenceTimer?.cancel();
    final finishedLessonId = _activeLessonId;
    final childId = _activeChildId ?? _ref.read(activeChildIdProvider);
    if (childId == null || finishedLessonId == null) return Future.value(null);
    final reward = _ref
        .read(lessonSyncServiceProvider)
        .lessonCompleted(finishedLessonId, childId)
        .timeout(_rewardTimeout, onTimeout: () => null);
    _completion = reward;
    _activeLessonId = null;
    _activeChildId = null;

    // Demo mode only — the backend owns both of these once it is on.
    _ref.read(demoProgressProvider.notifier).completeLesson();
    _ref.read(demoLessonProvider.notifier).completed(finishedLessonId);

    return reward;
  }

  /// Hands the reward to the screen that celebrates it.
  void publishReward(LessonReward? reward) =>
      _ref.read(lastLessonRewardProvider.notifier).set(reward);
}

final lessonSessionProvider = Provider<LessonSessionController>((ref) {
  final controller = LessonSessionController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
