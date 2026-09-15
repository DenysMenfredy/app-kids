import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/assessment.dart';

/// Source of the assessment: its questions, and the placement it produces.
abstract interface class AssessmentRepository {
  Future<Assessment> loadAssessment();

  /// Sends `{questionId: optionId}` for scoring. The backend decides the
  /// placement; the app never computes one.
  Future<AssessmentPlacement> submit({
    required String childId,
    required Map<String, String> answers,
  });
}

/// Demo mode: the MVP questions, mirroring `backend/seed/assessments/`.
class LocalAssessmentRepository implements AssessmentRepository {
  const LocalAssessmentRepository();

  static const _assessment = Assessment(
    id: 'assessment_pre_literacy_v1',
    title: 'Avaliação inicial',
    questions: [
      AssessmentQuestion(
        id: 'q_letters',
        prompt: '{name} já reconhece algumas letras?',
        options: [
          AssessmentOption(id: 'not_yet', label: 'Ainda não'),
          AssessmentOption(id: 'some', label: 'Algumas letras'),
          AssessmentOption(id: 'most', label: 'Quase todas'),
        ],
      ),
      AssessmentQuestion(
        id: 'q_writes_name',
        prompt: '{name} consegue escrever o próprio nome?',
        options: [
          AssessmentOption(id: 'not_yet', label: 'Ainda não'),
          AssessmentOption(id: 'with_help', label: 'Com ajuda'),
          AssessmentOption(id: 'alone', label: 'Sozinho(a)'),
        ],
      ),
      AssessmentQuestion(
        id: 'q_reading_together',
        prompt: 'Com que frequência vocês leem juntos?',
        options: [
          AssessmentOption(id: 'rarely', label: 'Raramente'),
          AssessmentOption(id: 'weekly', label: 'Algumas vezes por semana'),
          AssessmentOption(id: 'daily', label: 'Todos os dias'),
        ],
      ),
    ],
  );

  @override
  Future<Assessment> loadAssessment() async => _assessment;

  @override
  Future<AssessmentPlacement> submit({
    required String childId,
    required Map<String, String> answers,
  }) async => AssessmentPlacement.fallback;
}

class BackendAssessmentRepository implements AssessmentRepository {
  BackendAssessmentRepository(this._firestore, this._functions);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Future<Assessment> loadAssessment() async {
    final snapshot = await _firestore
        .doc('assessments/${AppConfig.defaultAssessmentId}')
        .get();
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Assessment ${AppConfig.defaultAssessmentId} not found');
    }
    return _assessmentFromMap(AppConfig.defaultAssessmentId, data);
  }

  @override
  Future<AssessmentPlacement> submit({
    required String childId,
    required Map<String, String> answers,
  }) async {
    final result = await _functions
        .httpsCallable('submitAssessment')
        .call<dynamic>({
          'childId': childId,
          'assessmentId': AppConfig.defaultAssessmentId,
          'answers': answers,
        });
    final placement = (result.data as Map)['placement'];
    if (placement is! Map) {
      throw StateError('submitAssessment returned no placement');
    }
    return AssessmentPlacement.fromMap(
      placement.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}

Assessment _assessmentFromMap(String id, Map<String, dynamic> data) {
  final rawQuestions =
      (data['questions'] as List? ?? const [])
          .whereType<Map>()
          .map((q) => q.map((key, value) => MapEntry(key.toString(), value)))
          .toList()
        // The document carries an explicit order; don't rely on array order.
        ..sort(
          (a, b) =>
              ((a['order'] as num?) ?? 0).compareTo((b['order'] as num?) ?? 0),
        );

  return Assessment(
    id: data['id'] as String? ?? id,
    title: data['title'] as String? ?? 'Avaliação',
    questions: [
      for (final question in rawQuestions)
        AssessmentQuestion(
          id: question['id'] as String? ?? '',
          prompt: question['prompt'] as String? ?? '',
          options: [
            for (final option
                in (question['options'] as List? ?? const []).whereType<Map>())
              AssessmentOption(
                id: option['id']?.toString() ?? '',
                label: option['label']?.toString() ?? '',
              ),
          ],
        ),
    ],
  );
}

final assessmentRepositoryProvider = Provider<AssessmentRepository>((ref) {
  if (AppConfig.useFirebase) {
    return BackendAssessmentRepository(
      ref.watch(firestoreProvider),
      ref.watch(functionsProvider),
    );
  }
  return const LocalAssessmentRepository();
});

/// The assessment to present. Loaded once per onboarding run.
final assessmentContentProvider = FutureProvider<Assessment>(
  (ref) => ref.watch(assessmentRepositoryProvider).loadAssessment(),
);
