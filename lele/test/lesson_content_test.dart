import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/config/app_config.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/features/lesson/data/lesson_repository.dart';
import 'package:lele/features/lesson/domain/lesson.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Documents in the shape the backend stores them (`backend/seed/lessons` +
/// `backend/seed/activities`). The values are representative rather than a
/// copy of any one lesson — the drift test below is what pins the offline
/// sample to the real seed.
const _lessonDoc = {
  'id': 'lesson_010',
  'moduleId': 'module_003',
  'number': 10,
  'order': 3,
  'title': 'Vamos brincar com a letra L!',
  'theme': 'Sons e rimas',
  'estimatedMinutes': 15,
  'published': true,
};

const _activityDocs = [
  {
    'id': 'activity_010_trace',
    'lessonId': 'lesson_010',
    'type': 'trace',
    'order': 3,
    'instruction': 'Trace a letra L com o dedo',
    'speech': 'Trace a letra éle',
    'letter': 'L',
  },
  {
    'id': 'activity_010_tap',
    'lessonId': 'lesson_010',
    'type': 'tap',
    'order': 1,
    'instruction': 'Toque na letra L',
    'speech': 'Toque na letra éle',
    'target': 'L',
    'options': [
      {'id': 'O', 'label': 'O', 'correct': false},
      {'id': 'L', 'label': 'L', 'correct': true},
      {'id': 'S', 'label': 'S', 'correct': false},
      {'id': 'A', 'label': 'A', 'correct': false},
    ],
  },
  {
    'id': 'activity_010_listen',
    'lessonId': 'lesson_010',
    'type': 'listen',
    'order': 4,
    'instruction': 'Qual palavra você ouviu?',
    'speech': 'lua',
    'answer': 'LUA',
    'options': [
      {'id': 'QUEIJO', 'label': 'QUEIJO', 'correct': false},
      {'id': 'LUA', 'label': 'LUA', 'correct': true},
      {'id': 'TATU', 'label': 'TATU', 'correct': false},
    ],
  },
  {
    'id': 'activity_010_match',
    'lessonId': 'lesson_010',
    'type': 'match',
    'order': 2,
    'instruction': 'Ligue as letras iguais',
    'hint': 'Toque na letra grande e depois na pequena',
    'pairs': [
      {'upper': 'L', 'lower': 'l'},
      {'upper': 'M', 'lower': 'm'},
      {'upper': 'N', 'lower': 'n'},
    ],
    'lowercaseOrder': ['m', 'n', 'l'],
  },
];

LessonContent parse({
  Map<String, dynamic> lesson = _lessonDoc,
  List<Map<String, dynamic>> activities = _activityDocs,
}) =>
    lessonContentFromMaps('lesson_010', lesson, activities);

void main() {
  group('lessonContentFromMaps', () {
    test('reads a lesson and its four activities', () {
      final content = parse();
      expect(content.id, 'lesson_010');
      expect(content.title, 'Vamos brincar com a letra L!');
      expect(content.theme, 'Sons e rimas');
      expect(content.estimatedMinutes, 15);
      expect(content.tap.target, 'L');
      expect(content.trace.letter, 'L');
      expect(content.listen.answer, 'LUA');
      expect(content.match.uppercase, ['L', 'M', 'N']);
    });

    test('keeps option order as stored, not answer-first', () {
      final content = parse();
      expect(content.tap.options, ['O', 'L', 'S', 'A']);
      expect(content.listen.options, ['QUEIJO', 'LUA', 'TATU']);
    });

    test('finds activities by type regardless of document order', () {
      // The fixture deliberately lists trace first.
      final content = parse();
      expect(content.tap.id, 'activity_010_tap');
      expect(content.match.id, 'activity_010_match');
    });

    test('carries the spoken form of the letter for TTS', () {
      final content = parse();
      expect(content.tap.speech, 'Toque na letra éle');
      expect(content.listen.speech, 'lua');
    });

    test('uses the stored right-column order for matching', () {
      final content = parse();
      expect(content.match.lowercase, ['m', 'n', 'l']);
      expect(content.match.lowercase, isNot(equals(['l', 'm', 'n'])));
    });

    test('falls back to derived lowercase when no order is stored', () {
      final activities = _activityDocs
          .map((a) => a['type'] == 'match'
              ? {
                  for (final entry in a.entries)
                    if (entry.key != 'lowercaseOrder') entry.key: entry.value,
                }
              : a)
          .toList();
      expect(parse(activities: activities).match.lowercase, ['l', 'm', 'n']);
    });

    test('rejects a lesson missing an activity type', () {
      final withoutTrace =
          _activityDocs.where((a) => a['type'] != 'trace').toList();
      expect(
        () => parse(activities: withoutTrace),
        throwsA(isA<StateError>()),
      );
    });

    test('survives a lesson document with fields missing', () {
      final content = parse(lesson: const {'id': 'lesson_010'});
      expect(content.title, 'Lição');
      expect(content.estimatedMinutes, 15);
    });
  });

  group('highlightSplit', () {
    test('splits around a letter at the end of the instruction', () {
      final parts = highlightSplit('Toque na letra L', 'L');
      expect(parts?.before, 'Toque na letra ');
      expect(parts?.after, '');
    });

    test('splits around a letter in the middle', () {
      final parts = highlightSplit('Trace a letra L com o dedo', 'L');
      expect(parts?.before, 'Trace a letra ');
      expect(parts?.after, ' com o dedo');
    });

    test('ignores the letter when it is part of another word', () {
      // "L" appears inside "Ligue", but not as its own word.
      expect(highlightSplit('Ligue as letras iguais', 'L'), isNull);
    });

    test('returns null for an empty token', () {
      expect(highlightSplit('Toque na letra', ''), isNull);
    });
  });

  group('LocalLessonRepository', () {
    test('serves the demo lesson whatever id is asked for', () async {
      final content =
          await const LocalLessonRepository().loadLesson('lesson_999');
      expect(content.id, AppConfig.demoLessonId);
      expect(content.tap.target, 'D');
    });

    test('matches what the backend seeds for that lesson', () async {
      // The offline sample is a copy of backend/seed — if the seed changes
      // and this doesn't, demo mode silently diverges from production.
      final seed = jsonDecode(
        File('../backend/seed/activities/activities.json').readAsStringSync(),
      ) as List;
      final seeded = seed
          .cast<Map<String, dynamic>>()
          .where((a) => a['lessonId'] == AppConfig.demoLessonId)
          .toList();
      final lessons = jsonDecode(
        File('../backend/seed/lessons/lessons.json').readAsStringSync(),
      ) as List;
      final seededLesson = lessons
          .cast<Map<String, dynamic>>()
          .firstWhere((l) => l['id'] == AppConfig.demoLessonId);

      final expected = lessonContentFromMaps(
        AppConfig.demoLessonId,
        seededLesson,
        seeded,
      );
      final actual =
          await const LocalLessonRepository().loadLesson(AppConfig.demoLessonId);
      expect(actual, expected);
    });
  });

  group('lesson content providers (local mode)', () {
    test('the current lesson resolves to the demo content', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(lessonRepositoryProvider),
          isA<LocalLessonRepository>());
      final content = await container
          .read(lessonContentProvider(AppConfig.demoLessonId).future);
      expect(content.listen.answer, 'DADO');
      expect(
        container.read(currentLessonContentProvider).value,
        content,
      );
    });
  });
}
