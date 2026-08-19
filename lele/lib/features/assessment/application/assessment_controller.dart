import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/assessment.dart';

class AssessmentState extends Equatable {
  const AssessmentState({this.step = 0, this.answers = const []});

  final int step;
  final List<int> answers;

  bool get isComplete => answers.length >= assessmentQuestions.length;

  AssessmentQuestion get currentQuestion => assessmentQuestions[step];

  @override
  List<Object?> get props => [step, answers];
}

class AssessmentController extends Notifier<AssessmentState> {
  @override
  AssessmentState build() => const AssessmentState();

  /// Records the answer for the current step. Returns true when the
  /// assessment is finished.
  bool answer(int optionIndex) {
    final answers = [...state.answers, optionIndex];
    final done = answers.length >= assessmentQuestions.length;
    state = AssessmentState(
      step: done ? state.step : state.step + 1,
      answers: answers,
    );
    return done;
  }

  void restart() => state = const AssessmentState();
}

final assessmentProvider =
    NotifierProvider<AssessmentController, AssessmentState>(
  AssessmentController.new,
);
