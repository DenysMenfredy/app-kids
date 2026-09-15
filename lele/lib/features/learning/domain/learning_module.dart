import 'package:equatable/equatable.dart';

enum ModuleStatus { done, current, locked }

/// Shape of the curriculum: which lessons belong to which module.
///
/// A mirror of `backend/seed/modules/` — titles, themes and lesson ranges
/// must match it, since the assessment result screen shows the backend's
/// module title while these screens show this copy. Kept in the app only
/// because the journey renders offline; serving modules from Firestore
/// would remove the duplication.
class CurriculumModule extends Equatable {
  const CurriculumModule({
    required this.number,
    required this.title,
    required this.lessonTheme,
    required this.firstLessonId,
    required this.lessonCount,
  });

  final int number;
  final String title;

  /// Short subtitle for the daily lesson, e.g. "Sons e rimas".
  final String lessonTheme;
  final String firstLessonId;
  final int lessonCount;

  int get firstLessonNumber => lessonNumberOf(firstLessonId) ?? 1;

  int get lastLessonNumber => firstLessonNumber + lessonCount - 1;

  @override
  List<Object?> get props => [number, title, firstLessonId, lessonCount];
}

const curriculum = [
  CurriculumModule(
    number: 1,
    title: 'Coordenação Motora e Vogais',
    lessonTheme: 'Letras e traçados',
    firstLessonId: 'lesson_001',
    lessonCount: 3,
  ),
  CurriculumModule(
    number: 2,
    title: 'Reconhecimento Visual',
    lessonTheme: 'Reconhecimento de letras',
    firstLessonId: 'lesson_004',
    lessonCount: 4,
  ),
  CurriculumModule(
    number: 3,
    title: 'Consciência Fonológica',
    lessonTheme: 'Sons iniciais e rimas',
    firstLessonId: 'lesson_008',
    lessonCount: 6,
  ),
  CurriculumModule(
    number: 4,
    title: 'Juntar Sons e Sílabas',
    lessonTheme: 'Juntar sons e sílabas',
    firstLessonId: 'lesson_014',
    lessonCount: 6,
  ),
  CurriculumModule(
    number: 5,
    title: 'Primeiras Palavras',
    lessonTheme: 'Ler palavras',
    firstLessonId: 'lesson_020',
    lessonCount: 6,
  ),
  CurriculumModule(
    number: 6,
    title: 'Juntar Palavras',
    lessonTheme: 'Juntar palavras',
    firstLessonId: 'lesson_026',
    lessonCount: 6,
  ),
  CurriculumModule(
    number: 7,
    title: 'Ler e Compreender Histórias',
    lessonTheme: 'Ler uma história',
    firstLessonId: 'lesson_032',
    lessonCount: 6,
  ),
];

/// One step of the journey, resolved for a particular child.
class LearningModule extends Equatable {
  const LearningModule({
    required this.number,
    required this.title,
    required this.lessonTheme,
    required this.status,
    this.progress = 0,
  });

  final int number;
  final String title;
  final String lessonTheme;
  final ModuleStatus status;

  /// 0..1 completion, only meaningful for the current module.
  final double progress;

  @override
  List<Object?> get props => [number, title, status, progress];
}

/// Parses the numeric suffix of a lesson id (`lesson_008` → 8). Null when the
/// id isn't in that shape.
int? lessonNumberOf(String lessonId) {
  final match = RegExp(r'^lesson_(\d+)$').firstMatch(lessonId);
  return match == null ? null : int.tryParse(match.group(1)!);
}

/// The lesson that follows this one, or null at the end of the curriculum.
/// Mirrors the backend's rule: lessons run in one unbroken sequence.
String? nextLessonId(String lessonId) {
  final number = lessonNumberOf(lessonId);
  if (number == null || number >= curriculum.last.lastLessonNumber) {
    return null;
  }
  return 'lesson_${(number + 1).toString().padLeft(3, '0')}';
}

/// The module a lesson belongs to, or null when it falls outside the
/// curriculum.
CurriculumModule? moduleForLesson(String lessonId) {
  final number = lessonNumberOf(lessonId);
  if (number == null) return null;
  for (final module in curriculum) {
    if (number >= module.firstLessonNumber &&
        number <= module.lastLessonNumber) {
      return module;
    }
  }
  return null;
}

/// Builds the journey around the child's current lesson: everything before
/// its module is done, its module is current, the rest are locked.
///
/// An unknown id starts the child at the beginning, and an id past the last
/// lesson keeps them on the final module — so there is always exactly one
/// current module for the screens to anchor on.
List<LearningModule> resolveJourney(String currentLessonId) {
  final last = curriculum.last;
  final lessonNumber = (lessonNumberOf(currentLessonId) ??
          curriculum.first.firstLessonNumber)
      .clamp(curriculum.first.firstLessonNumber, last.lastLessonNumber);

  return [
    for (final module in curriculum)
      LearningModule(
        number: module.number,
        title: module.title,
        lessonTheme: module.lessonTheme,
        status: lessonNumber > module.lastLessonNumber
            ? ModuleStatus.done
            : lessonNumber >= module.firstLessonNumber
                ? ModuleStatus.current
                : ModuleStatus.locked,
        progress: lessonNumber >= module.firstLessonNumber &&
                lessonNumber <= module.lastLessonNumber
            ? (lessonNumber - module.firstLessonNumber) / module.lessonCount
            : 0,
      ),
  ];
}
