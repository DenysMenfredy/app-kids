import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/features/lesson/data/lesson_sync_service.dart';
import 'package:lele/features/lesson/data/pending_lesson_store.dart';
import 'package:lele/features/lesson/domain/lesson_recovery.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Backend {
  bool offline = false;
  bool loseStart = false;
  bool loseAttempt = false;
  bool loseCompletion = false;
  bool deny = false;
  bool completed = false;
  Completer<void>? gate;
  final starts = <String>{};
  final accepted = <String>{};
  final calls = <({String name, Map<String, dynamic> data})>[];

  Future<Object?> call(String name, Map<String, dynamic> data) async {
    calls.add((name: name, data: Map.of(data)));
    if (offline) {
      throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
    }
    if (name == 'startLessonSession') {
      starts.add(data['requestId'] as String);
      if (loseStart) {
        throw FirebaseFunctionsException(
          code: 'unavailable',
          message: 'lost response',
        );
      }
      return {'sessionId': 'session-1'};
    }
    if (name == 'submitActivityAttempt') {
      if (deny) {
        throw FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'denied',
        );
      }
      if (gate != null) await gate!.future;
      accepted.add(data['requestId'] as String);
      if (loseAttempt) {
        throw FirebaseFunctionsException(
          code: 'unavailable',
          message: 'lost response',
        );
      }
      return {'ok': true};
    }
    if (name == 'recoverLessonSession') {
      return {
        'ok': true,
        'childId': data['childId'],
        'lessonId': data['lessonId'],
        'sessionId': data['sessionId'],
        'contentVersion': 1,
        'status': completed ? 'completed' : 'active',
        'nextActivityIndex': completed
            ? 4
            : accepted.isEmpty
            ? 0
            : 1,
        'lastLifecycleSequence': 9,
        'activityProgress': accepted.isEmpty
            ? <String, Object?>{}
            : {
                'tap-1': {
                  'completedItems': ['complete'],
                  'correctAnswers': 1,
                  'wrongAnswers': 0,
                },
              },
      };
    }
    if (name == 'completeLesson') {
      final awarded = !completed;
      completed = true;
      if (loseCompletion) {
        throw FirebaseFunctionsException(
          code: 'unavailable',
          message: 'lost response',
        );
      }
      return {
        'ok': true,
        'awarded': awarded,
        'xpEarned': awarded ? 50 : 0,
        'coinsEarned': awarded ? 10 : 0,
        'xp': 50,
        'coins': 10,
        'streak': 1,
      };
    }
    return {'ok': true};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;
  late PendingLessonStore store;
  late _Backend backend;
  CallableLessonSyncService service({bool Function()? authorized}) =>
      CallableLessonSyncService.withTransport(
        transport: backend.call,
        store: store,
        authorized: authorized,
        retryDelay: Duration.zero,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    store = PendingLessonStore(preferences, 'parent-a');
    backend = _Backend();
  });

  test(
    'a lost start response reuses the persisted request after process restart',
    () async {
      final first = service();
      backend.loseStart = true;
      await expectLater(
        first.lessonStarted('lesson_001', 'child-a', contentVersion: 1),
        throwsA(isA<FirebaseFunctionsException>()),
      );
      expect(backend.starts, hasLength(1));
      final pending = await store.load('child-a');
      expect(pending!.sessionId, isNull);
      first.close();
      backend.loseStart = false;
      final restored = service();
      expect((await restored.recover('child-a')).nextActivityIndex, 0);
      expect(backend.starts, {pending.requestId});
      expect((await store.load('child-a'))!.sessionId, 'session-1');
      restored.close();
    },
  );

  test(
    'exhausted answer retries remain durable and replay the same ID after reopen',
    () async {
      final first = service();
      await first.lessonStarted('lesson_001', 'child-a', contentVersion: 1);
      backend.loseAttempt = true; // committed on server, response lost
      await first.activityAttempt('lesson_001', 'child-a', 'tap-1', {
        'selectedLabel': 'A',
      });
      await expectLater(
        first.lessonCompleted('lesson_001', 'child-a'),
        throwsA(isA<FirebaseFunctionsException>()),
      );
      final queued = await store.load('child-a');
      expect(queued!.attempts, hasLength(1));
      expect(
        backend.calls.where((call) => call.name == 'completeLesson'),
        isEmpty,
      );
      first.close();
      backend.loseAttempt = false;
      final restored = service();
      final progress = await restored.recover('child-a');
      expect(progress.nextActivityIndex, 1);
      expect(progress.correctAnswers, 1);
      expect(progress.completedItems['tap-1'], {'complete'});
      expect(backend.accepted, {queued.attempts.single.requestId});
      expect((await store.load('child-a'))!.attempts, isEmpty);
      expect(
        (await restored.lessonCompleted('lesson_001', 'child-a'))!.xpEarned,
        50,
      );
      expect(await store.load('child-a'), isNull);
      restored.close();
    },
  );

  test(
    'a committed completion with a lost response confirms without another reward',
    () async {
      final first = service();
      await first.lessonStarted('lesson_001', 'child-a', contentVersion: 1);
      backend.loseCompletion = true;
      await expectLater(
        first.lessonCompleted('lesson_001', 'child-a'),
        throwsA(isA<FirebaseFunctionsException>()),
      );
      expect((await store.load('child-a'))!.completionRequested, isTrue);
      first.close();
      backend.loseCompletion = false;
      final restored = service();
      expect((await restored.recover('child-a')).nextActivityIndex, 4);
      final receipt = await restored.lessonCompleted('lesson_001', 'child-a');
      expect(receipt!.awarded, isFalse);
      expect(receipt.xp, 50);
      expect(receipt.xpEarned, 0);
      expect(await store.load('child-a'), isNull);
      restored.close();
    },
  );

  test(
    'each explicit flush tries permanent denial once and preserves the answer',
    () async {
      final sync = service();
      await sync.lessonStarted('lesson_001', 'child-a', contentVersion: 1);
      backend.deny = true;
      await sync.activityAttempt('lesson_001', 'child-a', 'tap-1', {
        'selectedLabel': 'A',
      });
      await expectLater(
        sync.lessonCompleted('lesson_001', 'child-a'),
        throwsA(isA<FirebaseFunctionsException>()),
      );
      expect(
        backend.calls.where((call) => call.name == 'submitActivityAttempt'),
        hasLength(2),
      );
      expect((await store.load('child-a'))!.attempts, hasLength(1));
      sync.close();
    },
  );

  test(
    'logout during an in-flight response clears recovery and cannot recreate it',
    () async {
      var currentOwner = true;
      final sync = service(authorized: () => currentOwner);
      await sync.lessonStarted('lesson_001', 'child-a', contentVersion: 1);
      backend.gate = Completer<void>();
      await sync.activityAttempt('lesson_001', 'child-a', 'tap-1', {
        'selectedLabel': 'A',
      });
      final completion = sync
          .lessonCompleted('lesson_001', 'child-a')
          .catchError((Object _) => null);
      await Future<void>.delayed(Duration.zero);
      currentOwner = false;
      await sync.clearLocalRecovery();
      backend.gate!.complete();
      await completion;
      expect(await store.load('child-a'), isNull);
      expect(
        backend.calls.where((call) => call.name == 'completeLesson'),
        isEmpty,
      );
    },
  );

  test(
    'parent and child namespaces isolate queues; logout clears only that owner',
    () async {
      final a = PendingLesson(
        childId: 'child-a',
        lessonId: 'lesson_001',
        requestId: 'start-a',
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      );
      await store.save(a);
      final other = PendingLessonStore(preferences, 'parent-b');
      expect(await other.load('child-a'), isNull);
      expect(await store.load('child-b'), isNull);
      await other.save(a.copyWith(sessionId: 'session-b'));
      await store.clearOwner();
      expect(await store.load('child-a'), isNull);
      expect((await other.load('child-a'))!.sessionId, 'session-b');
    },
  );

  test(
    'expired, malformed and oversized retry data is removed without sending',
    () async {
      final now = DateTime(2026, 10, 13, 12);
      store = PendingLessonStore(preferences, 'parent-a', now: () => now);
      await store.save(
        PendingLesson(
          childId: 'child-a',
          lessonId: 'lesson_001',
          requestId: 'old',
          createdAtMillis: now
              .subtract(const Duration(hours: 25))
              .millisecondsSinceEpoch,
        ),
      );
      expect(await service().pendingLesson('child-a'), isNull);
      await preferences.setString(
        'lesson.pending.v1.parent-a.child-a',
        '{broken',
      );
      expect(await store.load('child-a'), isNull);
      await preferences.setString(
        'lesson.pending.v1.parent-a.child-a',
        'x' * 250001,
      );
      expect(await store.load('child-a'), isNull);
      expect(backend.calls, isEmpty);
      await preferences.setInt('lesson.pending.v1.parent-a.child-a', 7);
      expect(await store.load('child-a'), isNull);
    },
  );

  test(
    'retry evidence rejects arbitrary data and preserves only bounded response fields',
    () {
      expect(
        boundedLessonResponse({
          'selectedLabel': 'A',
          'name': 'private',
          'correct': true,
        }),
        {'selectedLabel': 'A'},
      );
      expect(
        () => boundedLessonResponse({'selectedLabel': 'x' * 81}),
        throwsFormatException,
      );
      expect(
        () => boundedLessonResponse({
          'strokeCount': 1,
          'pointCount': 1001,
          'durationMillis': 200,
        }),
        throwsFormatException,
      );
      expect(
        () => boundedLessonResponse({'token': 'secret'}),
        throwsFormatException,
      );
    },
  );
}
