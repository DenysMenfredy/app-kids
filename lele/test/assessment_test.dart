import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/features/assessment/application/assessment_controller.dart';
import 'package:lele/features/assessment/data/assessment_repository.dart';
import 'package:lele/features/assessment/domain/assessment.dart';

class _RecordingRepository implements AssessmentRepository {
  _RecordingRepository({this.placement, this.failWith});

  final AssessmentPlacement? placement;
  final Object? failWith;
  Map<String, String>? submittedAnswers;
  String? submittedChildId;

  @override
  Future<Assessment> loadAssessment() async =>
      const LocalAssessmentRepository().loadAssessment();

  @override
  Future<AssessmentPlacement> submit({
    required String childId,
    required Map<String, String> answers,
  }) async {
    submittedChildId = childId;
    submittedAnswers = answers;
    if (failWith != null) throw failWith!;
    return placement!;
  }
}

ProviderContainer containerWith(AssessmentRepository repository) {
  final container = ProviderContainer(
    overrides: [assessmentRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

const _backendPlacement = AssessmentPlacement(
  moduleNumber: 1,
  moduleTitle: 'Coordenação Motora',
  description: 'Traçados e formas.',
  tags: ['15 min/dia', '4 semanas'],
);

void main() {
  group('AssessmentPlacement', () {
    test('parses a placement from the backend payload', () {
      final placement = AssessmentPlacement.fromMap(const {
        'moduleNumber': 4,
        'moduleTitle': 'Fônica',
        'description': 'Juntar sons e letras.',
        'tags': ['15 min/dia', '6 semanas'],
      });
      expect(placement.moduleNumber, 4);
      expect(placement.moduleTitle, 'Fônica');
      expect(placement.tags, ['15 min/dia', '6 semanas']);
    });

    test('falls back field by field on a malformed payload', () {
      final placement = AssessmentPlacement.fromMap(const {'moduleNumber': 2});
      expect(placement.moduleNumber, 2);
      expect(placement.moduleTitle, AssessmentPlacement.fallback.moduleTitle);
      expect(placement.tags, isEmpty);
    });
  });

  group('LocalAssessmentRepository', () {
    test('serves the MVP questions with stable option ids', () async {
      final assessment = await const LocalAssessmentRepository()
          .loadAssessment();
      expect(assessment.id, 'assessment_pre_literacy_v1');
      expect(assessment.questions, hasLength(3));
      expect(assessment.questions.map((q) => q.id), [
        'q_letters',
        'q_writes_name',
        'q_reading_together',
      ]);
      expect(assessment.questions.first.options.map((o) => o.id), [
        'not_yet',
        'some',
        'most',
      ]);
    });

    test('substitutes the child name into the prompt', () async {
      final assessment = await const LocalAssessmentRepository()
          .loadAssessment();
      expect(
        assessment.questions.first.promptFor('Sofia'),
        'Sofia já reconhece algumas letras?',
      );
    });
  });

  group('AssessmentController', () {
    test('records answers keyed by question id, not by index', () {
      final container = containerWith(_RecordingRepository());
      final controller = container.read(assessmentProvider.notifier);
      controller.record('q_letters', 'some');
      controller.record('q_writes_name', 'alone');

      expect(container.read(assessmentProvider).answers, {
        'q_letters': 'some',
        'q_writes_name': 'alone',
      });
      expect(container.read(assessmentProvider).step, 2);
    });

    test('submits the answers and keeps the backend placement', () async {
      final repository = _RecordingRepository(placement: _backendPlacement);
      final container = containerWith(repository);
      final controller = container.read(assessmentProvider.notifier);
      controller.record('q_letters', 'not_yet');

      final placement = await controller.submit(childId: 'primary');

      expect(placement, _backendPlacement);
      expect(repository.submittedChildId, 'primary');
      expect(repository.submittedAnswers, {'q_letters': 'not_yet'});
      final state = container.read(assessmentProvider);
      expect(state.placement, _backendPlacement);
      expect(state.usedFallback, isFalse);
      expect(state.submitting, isFalse);
    });

    test('falls back instead of dead-ending when the backend fails', () async {
      final container = containerWith(
        _RecordingRepository(failWith: Exception('offline')),
      );
      final controller = container.read(assessmentProvider.notifier);

      final placement = await controller.submit(childId: 'primary');

      expect(placement, AssessmentPlacement.fallback);
      final state = container.read(assessmentProvider);
      expect(state.usedFallback, isTrue);
      expect(state.submitting, isFalse);
    });

    test('restart clears answers and the previous placement', () async {
      final container = containerWith(
        _RecordingRepository(placement: _backendPlacement),
      );
      final controller = container.read(assessmentProvider.notifier);
      controller.record('q_letters', 'most');
      await controller.submit(childId: 'primary');

      controller.restart();

      final state = container.read(assessmentProvider);
      expect(state.answers, isEmpty);
      expect(state.placement, isNull);
      expect(state.step, 0);
    });
  });
}
