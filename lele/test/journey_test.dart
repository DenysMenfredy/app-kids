import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/config/app_config.dart';
import 'package:lele/features/learning/application/journey_provider.dart';
import 'package:lele/features/learning/domain/learning_module.dart';

List<int> _numbersWith(List<LearningModule> journey, ModuleStatus status) =>
    journey.where((m) => m.status == status).map((m) => m.number).toList();

void main() {
  group('lesson ids', () {
    test('parses the numeric suffix', () {
      expect(lessonNumberOf('lesson_001'), 1);
      expect(lessonNumberOf('lesson_014'), 14);
    });

    test('returns null for anything else', () {
      expect(lessonNumberOf('lesson_'), isNull);
      expect(lessonNumberOf('licao_008'), isNull);
      expect(lessonNumberOf(''), isNull);
    });

    test('maps a lesson to the module that contains it', () {
      expect(moduleForLesson('lesson_001')?.number, 1);
      expect(moduleForLesson('lesson_003')?.number, 1);
      expect(moduleForLesson('lesson_004')?.number, 2);
      expect(moduleForLesson('lesson_013')?.number, 3);
      expect(moduleForLesson('lesson_014')?.number, 4);
      expect(moduleForLesson('lesson_999'), isNull);
    });

    test('the app curriculum matches the backend modules', () {
      // Two copies of the module list exist: this one, and the seeded
      // documents the assessment result screen shows a title from. They
      // drifted once already, so the seed is the reference.
      final seeded = (jsonDecode(
        File('../backend/seed/modules/modules.json').readAsStringSync(),
      ) as List)
          .cast<Map<String, dynamic>>();

      expect(curriculum, hasLength(seeded.length));
      for (final module in seeded) {
        final own = curriculum.firstWhere((m) => m.number == module['number']);
        expect(own.title, module['title'], reason: 'title ${module['id']}');
        expect(own.lessonTheme, module['lessonTheme'],
            reason: 'theme ${module['id']}');
        expect(own.firstLessonId, module['firstLessonId'],
            reason: 'first lesson ${module['id']}');
        expect(own.lessonCount, module['lessonCount'],
            reason: 'lesson count ${module['id']}');
      }
    });

    test('every placement band in the backend seed resolves to a module', () {
      // backend/seed/assessments/assessment_pre_literacy_v1.json
      for (final firstLessonId in const [
        'lesson_001',
        'lesson_004',
        'lesson_008',
        'lesson_014',
      ]) {
        expect(moduleForLesson(firstLessonId), isNotNull,
            reason: firstLessonId);
      }
    });

    test('curriculum modules are contiguous', () {
      for (var i = 1; i < curriculum.length; i++) {
        expect(
          curriculum[i].firstLessonNumber,
          curriculum[i - 1].lastLessonNumber + 1,
          reason: 'gap before module ${curriculum[i].number}',
        );
      }
    });
  });

  group('resolveJourney', () {
    test('a child placed at the first lesson has nothing done yet', () {
      final journey = resolveJourney('lesson_001');
      expect(_numbersWith(journey, ModuleStatus.done), isEmpty);
      expect(_numbersWith(journey, ModuleStatus.current), [1]);
      expect(_numbersWith(journey, ModuleStatus.locked), [2, 3, 4, 5, 6, 7]);
    });

    test('a mid-curriculum placement marks earlier modules done', () {
      final journey = resolveJourney('lesson_010');
      expect(_numbersWith(journey, ModuleStatus.done), [1, 2]);
      expect(_numbersWith(journey, ModuleStatus.current), [3]);
      expect(_numbersWith(journey, ModuleStatus.locked), [4, 5, 6, 7]);
    });

    test('progress measures position inside the current module', () {
      // Module 3 runs lesson_008..lesson_013 (6 lessons).
      expect(resolveJourney('lesson_008')[2].progress, 0);
      expect(resolveJourney('lesson_010')[2].progress, closeTo(2 / 6, 1e-9));
      expect(resolveJourney('lesson_013')[2].progress, closeTo(5 / 6, 1e-9));
    });

    test('completed and locked modules carry no progress', () {
      final journey = resolveJourney('lesson_010');
      expect(journey[0].progress, 0);
      expect(journey[6].progress, 0);
    });

    test('the first lesson of a module starts that module, not the previous',
        () {
      expect(_numbersWith(resolveJourney('lesson_004'), ModuleStatus.current),
          [2]);
      expect(_numbersWith(resolveJourney('lesson_008'), ModuleStatus.current),
          [3]);
    });

    test('an unplaced or malformed lesson id starts at the beginning', () {
      expect(_numbersWith(resolveJourney(''), ModuleStatus.current), [1]);
      expect(
          _numbersWith(resolveJourney('nonsense'), ModuleStatus.current), [1]);
    });

    test('a lesson past the curriculum stays on the final module', () {
      final journey = resolveJourney('lesson_900');
      expect(_numbersWith(journey, ModuleStatus.current), [7]);
      expect(_numbersWith(journey, ModuleStatus.done), [1, 2, 3, 4, 5, 6]);
    });

    test('there is always exactly one current module', () {
      for (var lesson = 1; lesson <= 40; lesson++) {
        final id = 'lesson_${lesson.toString().padLeft(3, '0')}';
        expect(
          _numbersWith(resolveJourney(id), ModuleStatus.current),
          hasLength(1),
          reason: id,
        );
      }
    });
  });

  group('journey providers (local mode)', () {
    ProviderContainer makeContainer() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return container;
    }

    test('demo mode opens on the prototype lesson', () {
      final container = makeContainer();
      expect(container.read(currentLessonIdProvider), AppConfig.demoLessonId);
      expect(container.read(currentLessonNumberProvider), 10);
    });

    test('the current module matches the demo lesson', () {
      final container = makeContainer();
      final module = container.read(currentModuleProvider);
      expect(module.number, 3);
      expect(module.title, 'Consciência Fonológica');
      expect(module.lessonTheme, 'Sons iniciais e rimas');
      expect(module.progress, greaterThan(0));
    });

    test('journey and current module agree', () {
      final container = makeContainer();
      final journey = container.read(journeyProvider);
      final current = container.read(currentModuleProvider);
      expect(journey, hasLength(curriculum.length));
      expect(
        journey.singleWhere((m) => m.status == ModuleStatus.current),
        current,
      );
    });
  });
}
