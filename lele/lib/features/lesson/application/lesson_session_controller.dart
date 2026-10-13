import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../learning/application/journey_provider.dart';
import '../../session/application/child_provider.dart';
import '../../session/application/demo_progress_controller.dart';
import '../../session/application/session_controller.dart';
import '../data/lesson_sync_service.dart';
import '../domain/lesson_recovery.dart';
import '../domain/lesson_reward.dart';
import 'lesson_reward_provider.dart';
import 'lesson_stats_controller.dart';

class LessonRunController extends Notifier<LessonRecovery?> {
  @override
  LessonRecovery? build() {
    ref.watch(sessionStorageScopeProvider);
    return null;
  }

  void set(LessonRecovery? value) => state = value;
}

final lessonRunProvider =
    NotifierProvider<LessonRunController, LessonRecovery?>(
      LessonRunController.new,
    );

final pendingLessonProvider = FutureProvider.autoDispose<PendingLesson?>((ref) {
  ref.watch(sessionStorageScopeProvider);
  final child = ref.watch(activeChildIdProvider);
  final service = ref.watch(lessonSyncServiceProvider);
  return service is RecoverableLessonSyncService
      ? (service as RecoverableLessonSyncService).pendingLesson(child)
      : Future.value(null);
});

/// Owns a captured parent/child/lesson until confirmed completion or pause.
class LessonSessionController {
  LessonSessionController(this._ref);
  final Ref _ref;
  String? _activeChildId;
  String? _activeOwnerScope;
  String? _activeLessonId;
  Timer? _presenceTimer;
  bool _foreground = true;
  Future<LessonReward?>? _completion;
  Object? _run;
  bool _disposed = false;
  final _unsaved = <({String activityId, Map<String, Object?> response})>[];
  Future<bool>? _persisting;

  Future<bool> start({int? contentVersion, String? lessonId}) async {
    leave();
    final run = _run = Object();
    _completion = null;
    _unsaved.clear();
    _activeChildId = _ref.read(activeChildIdProvider);
    _activeOwnerScope = _ref.read(sessionStorageScopeProvider);
    _activeLessonId = lessonId ?? _ref.read(currentLessonIdProvider);
    _ref.read(lessonStatsProvider.notifier).start();
    try {
      await _ref
          .read(lessonSyncServiceProvider)
          .lessonStarted(
            _activeLessonId!,
            _activeChildId!,
            contentVersion: contentVersion,
          );
    } catch (_) {
      if (_run == run) _reset();
      return false;
    }
    if (!_valid(run)) return false;
    _ref
        .read(lessonRunProvider.notifier)
        .set(
          LessonRecovery(
            lessonId: _activeLessonId!,
            nextActivityIndex: 0,
            completedItems: const {},
            correctAnswers: 0,
            wrongAnswers: 0,
          ),
        );
    _startPresence();
    return true;
  }

  Future<LessonRecovery?> resume() async {
    leave();
    final service = _ref.read(lessonSyncServiceProvider);
    if (service is! RecoverableLessonSyncService) return null;
    final recoveryService = service as RecoverableLessonSyncService;
    final run = _run = Object();
    _completion = null;
    _unsaved.clear();
    _activeChildId = _ref.read(activeChildIdProvider);
    _activeOwnerScope = _ref.read(sessionStorageScopeProvider);
    try {
      final hint = await recoveryService.pendingLesson(_activeChildId!);
      if (!_valid(run) || hint == null) return null;
      _activeLessonId = hint.lessonId;
      final progress = await recoveryService.recover(_activeChildId!);
      if (!_valid(run)) return null;
      _ref.read(lessonRunProvider.notifier).set(progress);
      _ref
          .read(lessonStatsProvider.notifier)
          .restore(
            correct: progress.correctAnswers,
            wrong: progress.wrongAnswers,
          );
      _startPresence();
      return progress;
    } catch (_) {
      if (_valid(run)) _reset();
      return null;
    }
  }

  Future<bool> discardPending() async {
    leave();
    final service = _ref.read(lessonSyncServiceProvider);
    try {
      if (service is RecoverableLessonSyncService) {
        await (service as RecoverableLessonSyncService).discard(
          _ref.read(activeChildIdProvider),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _valid(Object? run) =>
      !_disposed &&
      run != null &&
      _run == run &&
      _activeOwnerScope == _ref.read(sessionStorageScopeProvider);

  void _startPresence() {
    _presenceTimer?.cancel();
    if (_ref.read(lessonSyncServiceProvider) is NoopLessonSyncService) return;
    _presenceTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_foreground) _lifecycle('heartbeat');
    });
  }

  void _lifecycle(String action) {
    if (_disposed ||
        _activeLessonId == null ||
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

  void _reset() {
    _presenceTimer?.cancel();
    _activeLessonId = null;
    _activeChildId = null;
    _activeOwnerScope = null;
    _run = null;
    _persisting = null;
    if (!_disposed) _ref.read(lessonRunProvider.notifier).set(null);
  }

  /// Leaving the screen pauses a recoverable run; restart explicitly abandons it.
  void leave() {
    _lifecycle('pause');
    _reset();
  }

  Future<void> clearRecoveryForSignOut() async {
    leave();
    final service = _ref.read(lessonSyncServiceProvider);
    if (service is RecoverableLessonSyncService) {
      await (service as RecoverableLessonSyncService).clearLocalRecovery();
      _ref.invalidate(lessonSyncServiceProvider);
    }
  }

  void dispose() {
    _disposed = true;
    _run = null;
    _presenceTimer?.cancel();
  }

  /// Persists bounded evidence before the exercise hands off to another screen.
  Future<bool> recordAttempt(String activityId, Map<String, Object?> response) {
    if (!_valid(_run) || _activeChildId == null || _activeLessonId == null) {
      return Future.value(false);
    }
    _unsaved.add((
      activityId: activityId,
      response: Map.unmodifiable(response),
    ));
    return persistAttempts();
  }

  Future<bool> persistAttempts() {
    if (_persisting != null) return _persisting!;
    final run = _run;
    final lesson = _activeLessonId;
    final child = _activeChildId;
    final service = _ref.read(lessonSyncServiceProvider);
    Future<bool> save() async {
      if (!_valid(run) || lesson == null || child == null) return false;
      try {
        while (_unsaved.isNotEmpty) {
          final attempt = _unsaved.first;
          await service.activityAttempt(
            lesson,
            child,
            attempt.activityId,
            attempt.response,
          );
          if (!_valid(run)) return false;
          _unsaved.removeAt(0);
        }
        return true;
      } catch (_) {
        return false;
      }
    }

    final pending = save();
    _persisting = pending;
    unawaited(
      pending.then((_) {
        if (identical(_persisting, pending)) _persisting = null;
      }),
    );
    return pending;
  }

  Future<LessonReward?> complete() {
    if (_valid(_run) && _completion != null) return _completion!;
    if (!_valid(_run) || _activeChildId == null || _activeLessonId == null) {
      return Future.value(null);
    }
    _presenceTimer?.cancel();
    final run = _run;
    final lessonId = _activeLessonId!;
    final childId = _activeChildId!;
    final service = _ref.read(lessonSyncServiceProvider);
    Future<LessonReward?> save() async {
      try {
        if (!await persistAttempts() || !_valid(run)) return null;
        final reward = await service.lessonCompleted(lessonId, childId);
        if (!_valid(run) || reward == null) return null;
        _ref.read(demoProgressProvider.notifier).completeLesson();
        _ref.read(demoLessonProvider.notifier).completed(lessonId);
        _activeLessonId = null;
        _activeChildId = null;
        return reward;
      } catch (_) {
        return null;
      }
    }

    final pending = save();
    _completion = pending;
    unawaited(
      pending.then((reward) {
        if (reward == null && identical(_completion, pending)) {
          _completion = null;
        }
      }),
    );
    return pending;
  }

  void publishReward(LessonReward? reward) =>
      _ref.read(lastLessonRewardProvider.notifier).set(reward);
}

final lessonSessionProvider = Provider<LessonSessionController>((ref) {
  final controller = LessonSessionController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
