import 'package:equatable/equatable.dart';

class AssessmentQuestion extends Equatable {
  const AssessmentQuestion({required this.question, required this.options});

  /// May contain `{name}` which is replaced with the child's name.
  final String question;
  final List<String> options;

  String questionFor(String childName) =>
      question.replaceAll('{name}', childName);

  @override
  List<Object?> get props => [question, options];
}

const assessmentQuestions = [
  AssessmentQuestion(
    question: '{name} já reconhece algumas letras?',
    options: ['Ainda não', 'Algumas letras', 'Quase todas'],
  ),
  AssessmentQuestion(
    question: '{name} consegue escrever o próprio nome?',
    options: ['Ainda não', 'Com ajuda', 'Sozinho(a)'],
  ),
  AssessmentQuestion(
    question: 'Com que frequência vocês leem juntos?',
    options: ['Raramente', 'Algumas vezes por semana', 'Todos os dias'],
  ),
];

/// Placement produced by the assessment. Static for the MVP: everyone starts
/// at module 3, matching the prototype.
class AssessmentResult extends Equatable {
  const AssessmentResult({
    required this.moduleNumber,
    required this.moduleTitle,
    required this.description,
    required this.tags,
  });

  final int moduleNumber;
  final String moduleTitle;
  final String description;
  final List<String> tags;

  static const placement = AssessmentResult(
    moduleNumber: 3,
    moduleTitle: 'Consciência Fonológica',
    description:
        'Brincadeiras com sons, rimas e sílabas — a base para ler as '
        'primeiras palavras.',
    tags: ['15 min/dia', '6 semanas'],
  );

  @override
  List<Object?> get props => [moduleNumber, moduleTitle, description, tags];
}
