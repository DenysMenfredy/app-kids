import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/assessment_repository.dart';
import '../domain/assessment.dart';

class AssessmentState extends Equatable {
  const AssessmentState({
    this.answers = const {},
    this.submitting = false,
    this.placement,
    this.usedFallback = false,
  });

  /// Chosen option id, keyed by question id.
  final Map<String, String> answers;
  final bool submitting;

  /// Set once the backend has scored the answers.
  final AssessmentPlacement? placement;

  /// True when the placement shown is the offline fallback, not the
  /// backend's answer.
  final bool usedFallback;

  /// Questions are answered in order, so the count is the current index.
  int get step => answers.length;

  AssessmentState copyWith({
    Map<String, String>? answers,
    bool? submitting,
    AssessmentPlacement? placement,
    bool? usedFallback,
  }) {
    return AssessmentState(
      answers: answers ?? this.answers,
      submitting: submitting ?? this.submitting,
      placement: placement ?? this.placement,
      usedFallback: usedFallback ?? this.usedFallback,
    );
  }

  @override
  List<Object?> get props => [answers, submitting, placement, usedFallback];
}

class AssessmentController extends Notifier<AssessmentState> {
  @override
  AssessmentState build() => const AssessmentState();

  /// Records the chosen option for a question.
  void record(String questionId, String optionId) {
    state = state.copyWith(
      answers: {...state.answers, questionId: optionId},
    );
  }

  /// Sends the answers for server-side scoring. Never throws: if the backend
  /// can't be reached the child still gets a journey from the fallback
  /// placement, and the next submission writes the real one (ADR 0003).
  Future<AssessmentPlacement> submit({required String childId}) async {
    state = state.copyWith(submitting: true);
    try {
      final placement =
          await ref.read(assessmentRepositoryProvider).submit(
                childId: childId,
                answers: state.answers,
              );
      state = state.copyWith(
        submitting: false,
        placement: placement,
        usedFallback: false,
      );
      return placement;
    } catch (error) {
      debugPrint('assessment submission failed: $error');
      state = state.copyWith(
        submitting: false,
        placement: AssessmentPlacement.fallback,
        usedFallback: true,
      );
      return AssessmentPlacement.fallback;
    }
  }

  void restart() => state = const AssessmentState();
}

final assessmentProvider =
    NotifierProvider<AssessmentController, AssessmentState>(
  AssessmentController.new,
);
