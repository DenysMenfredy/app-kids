import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/lesson.dart';
import '../domain/story.dart';

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
    title: 'O som da letra D',
    theme: 'Sons iniciais e rimas',
    estimatedMinutes: 15,
    tap: TapActivity(
      id: 'activity_010_tap',
      instruction: 'Toque na letra D',
      speech: 'Toque na letra dê',
      target: 'D',
      options: ['T', 'B', 'D', 'P'],
    ),
    match: MatchActivity(
      id: 'activity_010_match',
      instruction: 'Ligue as letras iguais',
      hint: 'Toque na letra grande e depois na pequena',
      uppercase: ['D', 'T', 'B'],
      lowercase: ['t', 'b', 'd'],
    ),
    trace: TraceActivity(
      id: 'activity_010_trace',
      instruction: 'Trace a letra D com o dedo',
      speech: 'Trace a letra dê',
      letter: 'D',
    ),
    listen: ListenActivity(
      id: 'activity_010_listen',
      instruction: 'Qual palavra você ouviu?',
      speech: 'dado',
      answer: 'DADO',
      options: ['DENTE', 'DADO', 'DEDO'],
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
      _firestore
          .doc('lessons/$lessonId')
          .get(const GetOptions(source: Source.server)),
      // `published` has to be part of the query, not just the rule: Firestore
      // evaluates a list against the query itself, so without this filter the
      // read is denied even though every document is published.
      _firestore
          .collection('activities')
          .where('lessonId', isEqualTo: lessonId)
          .where('published', isEqualTo: true)
          .orderBy('order')
          .get(const GetOptions(source: Source.server)),
    ]);
    final lesson = (results[0] as DocumentSnapshot<Map<String, dynamic>>)
        .data();
    if (lesson == null) {
      throw StateError('Lesson $lessonId not found');
    }
    final activities = (results[1] as QuerySnapshot<Map<String, dynamic>>).docs
        .map((doc) => {...doc.data(), 'id': doc.id})
        .toList();
    final storyActivities = activities.where(
      (activity) => activity['type'] == 'story',
    );
    Map<String, dynamic>? story;
    if (storyActivities.isNotEmpty) {
      final storyId = storyActivities.single['storyId'];
      if (storyId is! String) throw const FormatException('Missing story ID');
      story =
          (await _firestore
                  .doc('stories/$storyId')
                  .get(const GetOptions(source: Source.server)))
              .data();
      if (story == null) throw const FormatException('Story unavailable');
    }
    return lessonContentFromMaps(lessonId, lesson, activities, story: story);
  }
}

/// Builds a [LessonContent] from the raw documents.
///
/// Throws when an activity type is missing: better to fail on the intro
/// screen, where the child can retry, than part-way through a lesson.
LessonContent lessonContentFromMaps(
  String lessonId,
  Map<String, dynamic> lesson,
  List<Map<String, dynamic>> activities, {
  Map<String, dynamic>? story,
}) {
  final manifest = lesson['activityIds'];
  if (manifest != null) {
    if (manifest is! List ||
        ![4, 5].contains(manifest.length) ||
        manifest.length != activities.length ||
        manifest.toSet().length != manifest.length ||
        lesson['schemaVersion'] != 1 ||
        lesson['contentVersion'] is! int ||
        (lesson['contentVersion'] as int) < 1) {
      throw const FormatException('Invalid lesson manifest');
    }
    for (final (index, id) in manifest.indexed) {
      final matches = activities
          .where((activity) => activity['id'] == id)
          .toList();
      if (matches.length != 1 ||
          matches.single['order'] != index + 1 ||
          matches.single['lessonId'] != lessonId ||
          matches.single['schemaVersion'] != 1 ||
          matches.single['contentVersion'] is! int ||
          (matches.single['contentVersion'] as int) < 1) {
        throw const FormatException('Incomplete or mismatched lesson content');
      }
    }
  }
  Map<String, dynamic> activityOf(String type) {
    final match = activities.where((a) => a['type'] == type);
    if (match.length != 1) {
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
  final storyActivities = activities
      .where((activity) => activity['type'] == 'story')
      .toList();
  if (storyActivities.length > 1 ||
      activities.any(
        (activity) =>
            !ActivityType.values.any((type) => type.name == activity['type']),
      )) {
    throw const FormatException('Unsupported lesson activity');
  }

  final pairs = (match['pairs'] as List? ?? const []).whereType<Map>().toList();
  final uppercase = pairs
      .map((pair) => pair['upper']?.toString() ?? '')
      .toList();
  final lowercase =
      (match['lowercaseOrder'] as List?)
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
    contentVersion: lesson['contentVersion'] as int? ?? 1,
    story: storyActivities.isEmpty
        ? null
        : storyActivityFromMap(lessonId, storyActivities.single, story),
  );
}

StoryActivity storyActivityFromMap(
  String lessonId,
  Map<String, dynamic> activity,
  Map<String, dynamic>? raw,
) {
  if (raw == null ||
      raw['schemaVersion'] != 1 ||
      raw['id'] != activity['storyId'] ||
      raw['lessonId'] != lessonId ||
      raw['contentVersion'] is! int ||
      (raw['contentVersion'] as int) < 1 ||
      raw['pages'] is! List ||
      raw['questions'] is! List) {
    throw const FormatException('Invalid story contract');
  }
  String text(Map<String, dynamic> value, String key, int max) {
    final text = value[key];
    if (text is! String || text.trim().isEmpty || text.length > max) {
      throw const FormatException('Invalid story text');
    }
    return text;
  }

  const scenes = {
    'frog',
    'moon',
    'sun',
    'pond',
    'vowels',
    'party',
    'letters',
    'cat',
    'dog',
    'train',
    'flowers',
    'forest',
    'butterfly',
    'book',
    'family',
  };
  final pages = (raw['pages'] as List).map((value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid story page');
    }
    final scene = text(value, 'illustration', 32);
    if (!scenes.contains(scene) ||
        value.containsKey('audioUrl') ||
        value.containsKey('imageUrl')) {
      throw const FormatException('Unsupported story media');
    }
    return StoryPage(
      id: text(value, 'id', 64),
      text: text(value, 'text', 1200),
      illustration: scene,
    );
  }).toList();
  final questions = (raw['questions'] as List).map((value) {
    if (value is! Map<String, dynamic> || value['options'] is! List) {
      throw const FormatException('Invalid story question');
    }
    final options = (value['options'] as List).map((option) {
      if (option is! String || option.trim().isEmpty || option.length > 80) {
        throw const FormatException('Invalid option');
      }
      return option;
    }).toList();
    final answer = text(value, 'answer', 80);
    if (options.length < 2 ||
        options.length > 4 ||
        options.toSet().length != options.length ||
        !options.contains(answer)) {
      throw const FormatException('Invalid story answer');
    }
    return StoryQuestion(
      id: text(value, 'id', 64),
      prompt: text(value, 'question', 300),
      options: options,
      answer: answer,
    );
  }).toList();
  if (pages.isEmpty ||
      pages.length > 12 ||
      questions.isEmpty ||
      questions.length > 8 ||
      pages.map((page) => page.id).toSet().length != pages.length ||
      questions.map((question) => question.id).toSet().length !=
          questions.length) {
    throw const FormatException('Incomplete story');
  }
  return StoryActivity(
    id: text(activity, 'id', 64),
    storyId: text(raw, 'id', 64),
    title: text(raw, 'title', 100),
    contentVersion: raw['contentVersion'] as int,
    pages: List.unmodifiable(pages),
    questions: List.unmodifiable(questions),
  );
}

final lessonRepositoryProvider = Provider<LessonRepository>((ref) {
  if (AppConfig.useFirebase) {
    return FirestoreLessonRepository(ref.watch(firestoreProvider));
  }
  return const LocalLessonRepository();
});
