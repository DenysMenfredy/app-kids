import 'package:equatable/equatable.dart';

enum ModuleStatus { done, current, locked }

/// One step of the 7-module learning journey
/// (fine motor skills → stories).
class LearningModule extends Equatable {
  const LearningModule({
    required this.number,
    required this.title,
    required this.status,
    this.progress = 0,
  });

  final int number;
  final String title;
  final ModuleStatus status;

  /// 0..1 completion, only meaningful for the current module.
  final double progress;

  @override
  List<Object?> get props => [number, title, status, progress];
}

/// MVP journey snapshot. Later this comes from the curriculum backend keyed
/// by the child's assessment result.
const learningJourney = [
  LearningModule(
      number: 1, title: 'Coordenação Motora', status: ModuleStatus.done),
  LearningModule(
      number: 2, title: 'Reconhecimento Visual', status: ModuleStatus.done),
  LearningModule(
    number: 3,
    title: 'Consciência Fonológica',
    status: ModuleStatus.current,
    progress: 0.42,
  ),
  LearningModule(number: 4, title: 'Fônica', status: ModuleStatus.locked),
  LearningModule(number: 5, title: 'Palavras', status: ModuleStatus.locked),
  LearningModule(number: 6, title: 'Frases', status: ModuleStatus.locked),
  LearningModule(number: 7, title: 'Histórias', status: ModuleStatus.locked),
];
