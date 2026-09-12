import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../learning/application/journey_provider.dart';
import '../domain/lesson.dart';

/// Source of a lesson's exercises.
abstract interface class LessonRepository {
  Future<LessonContent> loadLesson(String lessonId);
}

/// Demo mode plays one sample lesson — the content the backend serves for
/// [AppConfig.demoLessonId], copied from `backend/seed/`, so the offline app
/// shows the same exercises it would online.
class LocalLessonRepository implements LessonRepository {
  const LocalLessonRepository();

  static const _sample = LessonContent(
    id: 'lesson_010',
    title: 'Vamos brincar com a letra L!',
    theme: 'Sons e rimas',
    estimatedMinutes: 15,
    tap: TapActivity(
      id: 'activity_010_tap',
      instruction: 'Toque na letra L',
      speech: 'Toque na letra éle',
      target: 'L',
      options: ['O', 'L', 'S', 'A'],
    ),
    match: MatchActivity(
      id: 'activity_010_match',
      instruction: 'Ligue as letras iguais',
      hint: 'Toque na letra grande e depois na pequena',
      uppercase: ['L', 'M', 'N'],
      lowercase: ['m', 'n', 'l'],
    ),
    trace: TraceActivity(
      id: 'activity_010_trace',
      instruction: 'Trace a letra L com o dedo',
      speech: 'Trace a letra éle',
      letter: 'L',
    ),
    listen: ListenActivity(
      id: 'activity_010_listen',
      instruction: 'Qual palavra você ouviu?',
      speech: 'lua',
      answer: 'LUA',
      options: ['QUEIJO', 'LUA', 'TATU'],
    ),
  );

  @override
  Future<LessonContent> loadLesson(String lessonId) async => _sample;
}

class FirestoreLessonRepository implements LessonRepository {
  FirestoreLessonRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<LessonContent> loadLesson(String lessonId) async {
    final results = await Future.wait([
      _firestore.doc('lessons/$lessonId').get(),
      _firestore
          .collection('activities')
          .where('lessonId', isEqualTo: lessonId)
          .orderBy('order')
          .get(),
    ]);
    final lesson = (results[0] as DocumentSnapshot<Map<String, dynamic>>).data();
    if (lesson == null) {
      throw StateError('Lesson $lessonId not found');
    }
    final activities = (results[1] as QuerySnapshot<Map<String, dynamic>>).docs
        .map((doc) => {...doc.data(), 'id': doc.id})
        .toList();
    return lessonContentFromMaps(lessonId, lesson, activities);
  }
}

/// Builds a [LessonContent] from the raw documents.
///
/// Throws when an activity type is missing: better to fail on the intro
/// screen, where the child can retry, than part-way through a lesson.
LessonContent lessonContentFromMaps(
  String lessonId,
  Map<String, dynamic> lesson,
  List<Map<String, dynamic>> activities,
) {
  Map<String, dynamic> activityOf(String type) {
    final match = activities.where((a) => a['type'] == type);
    if (match.isEmpty) {
      throw StateError('Lesson $lessonId has no "$type" activity');
    }
    return match.first;
  }

  String text(Map<String, dynamic> map, String key, {String fallback = ''}) =>
      map[key] as String? ?? fallback;

  List<String> labels(Map<String, dynamic> activity) =>
      (activity['options'] as List? ?? const [])
          .whereType<Map>()
          .map((option) => option['label']?.toString() ?? '')
          .where((label) => label.isNotEmpty)
          .toList();

  final tap = activityOf('tap');
  final match = activityOf('match');
  final trace = activityOf('trace');
  final listen = activityOf('listen');

  final pairs = (match['pairs'] as List? ?? const []).whereType<Map>().toList();
  final uppercase =
      pairs.map((pair) => pair['upper']?.toString() ?? '').toList();
  final lowercase = (match['lowercaseOrder'] as List?)
          ?.map((letter) => letter.toString())
          .toList() ??
      uppercase.map((letter) => letter.toLowerCase()).toList();

  return LessonContent(
    id: lessonId,
    title: text(lesson, 'title', fallback: 'Lição'),
    theme: text(lesson, 'theme'),
    estimatedMinutes: (lesson['estimatedMinutes'] as num?)?.toInt() ?? 15,
    tap: TapActivity(
      id: text(tap, 'id'),
      instruction: text(tap, 'instruction'),
      speech: text(tap, 'speech'),
      target: text(tap, 'target'),
      options: labels(tap),
    ),
    match: MatchActivity(
      id: text(match, 'id'),
      instruction: text(match, 'instruction'),
      hint: text(match, 'hint'),
      uppercase: uppercase,
      lowercase: lowercase,
    ),
    trace: TraceActivity(
      id: text(trace, 'id'),
      instruction: text(trace, 'instruction'),
      speech: text(trace, 'speech'),
      letter: text(trace, 'letter'),
    ),
    listen: ListenActivity(
      id: text(listen, 'id'),
      instruction: text(listen, 'instruction'),
      speech: text(listen, 'speech'),
      answer: text(listen, 'answer'),
      options: labels(listen),
    ),
  );
}

final lessonRepositoryProvider = Provider<LessonRepository>((ref) {
  if (AppConfig.useFirebase) {
    return FirestoreLessonRepository(ref.watch(firestoreProvider));
  }
  return const LocalLessonRepository();
});

/// Content for one lesson, cached for the whole run of that lesson: the
/// activities hand off to each other, and a dropped connection mid-lesson
/// must not strand the child on a spinner.
final lessonContentProvider =
    FutureProvider.family<LessonContent, String>((ref, lessonId) {
  ref.keepAlive();
  return ref.watch(lessonRepositoryProvider).loadLesson(lessonId);
});

/// Content for the lesson the child is currently on. Forwards the cached
/// [AsyncValue] without adding another async hop, so moving between
/// activities never flashes a loading state.
final currentLessonContentProvider = Provider<AsyncValue<LessonContent>>(
  (ref) => ref.watch(lessonContentProvider(ref.watch(currentLessonIdProvider))),
);
