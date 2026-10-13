import 'dart:async';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/storage/local_storage.dart';
import '../domain/lesson_recovery.dart';
import '../domain/lesson_reward.dart';
import 'pending_lesson_store.dart';

abstract interface class LessonSyncService {
  Future<void> sessionLifecycle(String lessonId, String childId, String action);
  Future<void> lessonStarted(
    String lessonId,
    String childId, {
    int? contentVersion,
  });
  Future<void> activityAttempt(
    String lessonId,
    String childId,
    String activityId,
    Map<String, Object?> response,
  );
  Future<LessonReward?> lessonCompleted(String lessonId, String childId);
}

abstract interface class RecoverableLessonSyncService {
  Future<PendingLesson?> pendingLesson(String childId);
  Future<LessonRecovery> recover(String childId);
  Future<void> discard(String childId);
  Future<void> clearLocalRecovery();
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
  Future<void> lessonStarted(
    String lessonId,
    String childId, {
    int? contentVersion,
  }) async {}
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

typedef LessonTransport =
    Future<Object?> Function(String name, Map<String, dynamic> data);

class _Run {
  _Run(this.lesson);
  PendingLesson lesson;
  Future<void> mutations = Future.value();
  Future<void>? sending;
  LessonReward? reward;
}

/// Persists requests before sending. Only acknowledged answers leave the queue.
/// Replays preserve IDs across retries and process restarts; the server scores
/// answers and decides completion. The store never contains lesson payloads.
class CallableLessonSyncService
    implements LessonSyncService, RecoverableLessonSyncService {
  CallableLessonSyncService(
    FirebaseFunctions functions, {
    required PendingLessonStore store,
    required bool Function() authorized,
  }) : this.withTransport(
         transport: (name, data) async =>
             (await functions.httpsCallable(name).call<dynamic>(data)).data,
         store: store,
         authorized: authorized,
       );

  CallableLessonSyncService.withTransport({
    required LessonTransport transport,
    required PendingLessonStore store,
    bool Function()? authorized,
    this.retryDelay = const Duration(milliseconds: 200),
    this.callTimeout = const Duration(seconds: 8),
  }) : _transport = transport,
       _store = store,
       _authorized = authorized ?? (() => true);

  final LessonTransport _transport;
  final PendingLessonStore _store;
  final bool Function() _authorized;
  final Duration retryDelay;
  final Duration callTimeout;
  final _runs = <String, _Run>{};
  final _random = Random.secure();
  bool _closed = false;

  String _requestId() => List.generate(
    16,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  void _check([_Run? run]) {
    if (_closed ||
        !_authorized() ||
        (run != null && !identical(_runs[run.lesson.childId], run))) {
      throw StateError('Lesson scope changed');
    }
  }

  Future<_Run?> _load(String childId) async {
    _check();
    final current = _runs[childId];
    if (current != null) return current.reward == null ? current : null;
    final lesson = await _store.load(childId);
    _check();
    if (lesson == null) return null;
    return _runs.putIfAbsent(childId, () => _Run(lesson));
  }

  @override
  Future<PendingLesson?> pendingLesson(String childId) async =>
      (await _load(childId))?.lesson;

  Future<void> _mutate(_Run run, Future<void> Function() action) {
    final next = run.mutations.then((_) async {
      _check(run);
      await action();
    });
    // A failed disk write surfaces without poisoning later retry operations.
    // Network calls are kept outside this short queue.
    run.mutations = next.catchError((Object _) {});
    return next;
  }

  Future<void> _save(_Run run, PendingLesson next) async {
    await _store.save(next);
    _check(run);
    run.lesson = next;
  }

  Future<void> _ensureSession(_Run run, {bool revalidate = false}) async {
    if (run.lesson.sessionId != null && !revalidate) return;
    final data = await _call('startLessonSession', {
      'childId': run.lesson.childId,
      'lessonId': run.lesson.lessonId,
      'requestId': run.lesson.requestId,
      'contentVersion': ?run.lesson.contentVersion,
    });
    if (data is! Map || data['sessionId'] is! String) {
      throw StateError('Session not confirmed');
    }
    await _mutate(
      run,
      () => _save(
        run,
        run.lesson.copyWith(sessionId: data['sessionId'] as String),
      ),
    );
  }

  @override
  Future<void> lessonStarted(
    String lessonId,
    String childId, {
    int? contentVersion,
  }) async {
    var run = await _load(childId);
    if (run != null &&
        (run.lesson.lessonId != lessonId ||
            run.lesson.contentVersion != contentVersion)) {
      await discard(childId);
      run = null;
    }
    if (run == null) {
      run = _Run(
        PendingLesson(
          childId: childId,
          lessonId: lessonId,
          requestId: _requestId(),
          contentVersion: contentVersion,
          createdAtMillis: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      _runs[childId] = run;
      final starting = run;
      await _mutate(starting, () => _store.save(starting.lesson));
    }
    await _ensureSession(run, revalidate: true);
  }

  @override
  Future<void> activityAttempt(
    String lessonId,
    String childId,
    String activityId,
    Map<String, Object?> response,
  ) async {
    final run = await _load(childId);
    if (run == null || run.lesson.lessonId != lessonId) {
      throw StateError('No active lesson');
    }
    final answer = PendingLessonAttempt(
      requestId: _requestId(),
      activityId: activityId,
      response: boundedLessonResponse(response),
    );
    await _mutate(
      run,
      () => _save(
        run,
        run.lesson.copyWith(
          attempts: List.unmodifiable([...run.lesson.attempts, answer]),
        ),
      ),
    );
    // Saving the reward waits for every answer to be acknowledged.
    unawaited(_flush(run).catchError((Object _) {}));
  }

  Future<void> _flush(_Run run) {
    if (run.sending != null) return run.sending!;
    final sending = _sendPending(run);
    run.sending = sending;
    unawaited(
      sending.then<void>(
        (_) {
          run.sending = null;
        },
        onError: (Object _, StackTrace _) {
          run.sending = null;
        },
      ),
    );
    return sending;
  }

  Future<void> _sendPending(_Run run) async {
    await _ensureSession(run);
    while (true) {
      await run.mutations;
      _check(run);
      if (run.lesson.attempts.isEmpty) return;
      final attempt = run.lesson.attempts.first;
      final result = await _call('submitActivityAttempt', {
        'childId': run.lesson.childId,
        'sessionId': run.lesson.sessionId,
        'activityId': attempt.activityId,
        'requestId': attempt.requestId,
        'response': attempt.response,
      });
      if (result is! Map || result['ok'] != true) {
        throw StateError('Answer not confirmed');
      }
      await _mutate(
        run,
        () => _save(
          run,
          run.lesson.copyWith(
            attempts: List.unmodifiable(
              run.lesson.attempts.where(
                (item) => item.requestId != attempt.requestId,
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Future<LessonReward?> lessonCompleted(String lessonId, String childId) async {
    final known = _runs[childId];
    if (known?.reward != null && known!.lesson.lessonId == lessonId) {
      return known.reward;
    }
    final run = await _load(childId);
    if (run == null || run.lesson.lessonId != lessonId) return null;
    await _mutate(
      run,
      () => _save(run, run.lesson.copyWith(completionRequested: true)),
    );
    await _flush(run);
    final data = await _call('completeLesson', {
      'childId': childId,
      'lessonId': lessonId,
      'sessionId': run.lesson.sessionId,
    });
    if (data is! Map || data['ok'] != true) return null;
    _check(run);
    final reward = LessonReward.fromMap(
      data.map((key, value) => MapEntry(key.toString(), value)),
    );
    await _mutate(run, () async {
      await _store.remove(childId);
      run.reward = reward;
    });
    return reward;
  }

  @override
  Future<LessonRecovery> recover(String childId) async {
    final run = await _load(childId);
    if (run == null) throw StateError('No pending lesson');
    await _ensureSession(run);
    Future<Map> read() async {
      final data = await _call('recoverLessonSession', {
        'childId': childId,
        'lessonId': run.lesson.lessonId,
        'sessionId': run.lesson.sessionId,
      });
      if (data is! Map ||
          data['ok'] != true ||
          data['childId'] != childId ||
          data['lessonId'] != run.lesson.lessonId ||
          data['sessionId'] != run.lesson.sessionId ||
          (run.lesson.contentVersion != null &&
              data['contentVersion'] != run.lesson.contentVersion)) {
        throw const FormatException('Invalid recovery state');
      }
      final sequence = data['lastLifecycleSequence'];
      if (sequence is! int || sequence < 0) {
        throw const FormatException('Invalid session sequence');
      }
      await _mutate(
        run,
        () => _save(run, run.lesson.copyWith(lifecycleSequence: sequence)),
      );
      return data;
    }

    var data = await read();
    final queued = run.lesson.attempts.isNotEmpty;
    await _flush(run);
    if (queued) data = await read();
    final index = data['nextActivityIndex'];
    final progress = data['activityProgress'];
    if (index is! int || index < 0 || index > 5 || progress is! Map) {
      throw const FormatException('Invalid session progress');
    }
    final items = <String, Set<String>>{};
    var correct = 0;
    var wrong = 0;
    for (final entry in progress.entries) {
      final value = entry.value;
      if (entry.key is! String ||
          value is! Map ||
          value['completedItems'] is! List ||
          value['correctAnswers'] is! int ||
          value['wrongAnswers'] is! int) {
        throw const FormatException('Invalid activity progress');
      }
      items[entry.key as String] = Set.unmodifiable(
        (value['completedItems'] as List).cast<String>(),
      );
      correct += value['correctAnswers'] as int;
      wrong += value['wrongAnswers'] as int;
    }
    return LessonRecovery(
      lessonId: run.lesson.lessonId,
      nextActivityIndex: index,
      completedItems: Map.unmodifiable(items),
      correctAnswers: correct,
      wrongAnswers: wrong,
    );
  }

  @override
  Future<void> sessionLifecycle(
    String lessonId,
    String childId,
    String action,
  ) async {
    try {
      final run = await _load(childId);
      if (run == null ||
          run.lesson.lessonId != lessonId ||
          run.lesson.sessionId == null) {
        return;
      }
      late int sequence;
      await _mutate(run, () async {
        sequence = run.lesson.lifecycleSequence + 1;
        await _save(run, run.lesson.copyWith(lifecycleSequence: sequence));
      });
      await _call('updateLessonSession', {
        'childId': childId,
        'sessionId': run.lesson.sessionId,
        'sequence': sequence,
        'action': action,
      });
    } catch (_) {
      // Later recovery rechecks access and excludes the inactive gap.
    }
  }

  @override
  Future<void> discard(String childId) async {
    final run = await _load(childId);
    if (run != null) {
      await run.mutations;
      _runs.remove(childId);
      if (run.lesson.sessionId != null) {
        unawaited(
          _call('updateLessonSession', {
            'childId': childId,
            'sessionId': run.lesson.sessionId,
            'action': 'abandon',
            'sequence': run.lesson.lifecycleSequence + 1,
          }, retry: false).catchError((Object _) => null),
        );
      }
    }
    await _store.remove(childId);
  }

  void close() {
    _closed = true;
  }

  @override
  Future<void> clearLocalRecovery() async {
    close();
    await Future.wait(_runs.values.map((run) => run.mutations));
    await _store.clearOwner();
    _runs.clear();
  }

  Future<Object?> _call(
    String name,
    Map<String, dynamic> data, {
    bool retry = true,
  }) async {
    for (var attempt = 0; ; attempt++) {
      _check();
      try {
        final result = await _transport(name, data).timeout(callTimeout);
        _check();
        return result;
      } catch (error) {
        final transient =
            error is TimeoutException ||
            (error is FirebaseFunctionsException &&
                [
                  'unavailable',
                  'deadline-exceeded',
                  'internal',
                  'aborted',
                ].contains(error.code));
        if (!retry || !transient || attempt == 2) rethrow;
        await Future<void>.delayed(retryDelay * (attempt + 1));
      }
    }
  }
}

final lessonSyncServiceProvider = Provider<LessonSyncService>((ref) {
  if (!AppConfig.useFirebase) return const NoopLessonSyncService();
  ref.watch(firebaseAuthUserProvider.select((state) => state.value?.uid));
  final auth = ref.read(firebaseAuthProvider);
  final uid = auth.currentUser?.uid ?? 'signed-out';
  final service = CallableLessonSyncService(
    ref.watch(functionsProvider),
    store: PendingLessonStore(ref.watch(sharedPreferencesProvider), uid),
    authorized: () => auth.currentUser?.uid == uid,
  );
  ref.onDispose(() {
    service.close();
    if (auth.currentUser?.uid != uid) unawaited(service.clearLocalRecovery());
  });
  return service;
});
