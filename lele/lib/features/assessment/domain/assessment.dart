import 'package:equatable/equatable.dart';

/// Assessment content as served by the backend (`assessments/{id}`).
///
/// The app renders labels and reports which option was chosen. Option
/// weights and placement thresholds are stored alongside in Firestore but
/// are deliberately not modelled here: scoring happens server-side, so the
/// client has no rule it could apply to place itself (ADR 0003).
class AssessmentOption extends Equatable {
  const AssessmentOption({required this.id, required this.label});

  final String id;
  final String label;

  @override
  List<Object?> get props => [id, label];
}

class AssessmentQuestion extends Equatable {
  const AssessmentQuestion({
    required this.id,
    required this.prompt,
    required this.options,
  });

  final String id;

  /// May contain `{name}`, replaced with the child's name for display.
  final String prompt;
  final List<AssessmentOption> options;

  String promptFor(String childName) => prompt.replaceAll('{name}', childName);

  @override
  List<Object?> get props => [id, prompt, options];
}

class Assessment extends Equatable {
  const Assessment({
    required this.id,
    required this.title,
    required this.questions,
  });

  final String id;
  final String title;
  final List<AssessmentQuestion> questions;

  @override
  List<Object?> get props => [id, title, questions];
}

/// Where the child starts on the learning journey, decided by the backend.
class AssessmentPlacement extends Equatable {
  const AssessmentPlacement({
    required this.moduleNumber,
    required this.moduleTitle,
    required this.description,
    required this.tags,
  });

  final int moduleNumber;
  final String moduleTitle;
  final String description;
  final List<String> tags;

  /// Shown in demo mode, and when the backend can't be reached — onboarding
  /// never dead-ends on a network problem. The real placement is written on
  /// the next successful submission.
  static const fallback = AssessmentPlacement(
    moduleNumber: 3,
    moduleTitle: 'Consciência Fonológica',
    description:
        'Brincadeiras com sons, rimas e sílabas — a base para ler as '
        'primeiras palavras.',
    tags: ['15 min/dia', '6 semanas'],
  );

  factory AssessmentPlacement.fromMap(Map<String, dynamic> map) {
    return AssessmentPlacement(
      moduleNumber: (map['moduleNumber'] as num?)?.toInt() ??
          fallback.moduleNumber,
      moduleTitle: map['moduleTitle'] as String? ?? fallback.moduleTitle,
      description: map['description'] as String? ?? fallback.description,
      tags: (map['tags'] as List?)?.whereType<String>().toList() ??
          const <String>[],
    );
  }

  @override
  List<Object?> get props => [moduleNumber, moduleTitle, description, tags];
}
