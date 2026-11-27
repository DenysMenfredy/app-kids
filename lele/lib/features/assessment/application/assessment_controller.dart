import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/consent/parent_consent.dart';
import '../data/assessment_repository.dart';
import '../domain/assessment.dart';

class AssessmentState extends Equatable {
  const AssessmentState({
    this.answers = const {},
    this.submitting = false,
    this.placement,
    this.usedFallback = false,
    this.consentRequired = false,
  });

  /// Chosen option id, keyed by question id.
  final Map<String, String> answers;
  final bool submitting;

  /// Set once the backend has scored the answers.
  final AssessmentPlacement? placement;

  /// True when the placement shown is the offline fallback, not the
  /// backend's answer.
  final bool usedFallback;

  /// True when the backend refused the submission until the parent accepts
  /// the current terms. The question screen asks for that acceptance and
  /// retries instead of showing the fallback as if it were scored.
  final bool consentRequired;

  /// Questions are answered in order, so the count is the current index.
  int get step => answers.length;

  AssessmentState copyWith({
    Map<String, String>? answers,
    bool? submitting,
    AssessmentPlacement? placement,
    bool? usedFallback,
    bool? consentRequired,
  }) {
    return AssessmentState(
      answers: answers ?? this.answers,
      submitting: submitting ?? this.submitting,
      placement: placement ?? this.placement,
      usedFallback: usedFallback ?? this.usedFallback,
      consentRequired: consentRequired ?? this.consentRequired,
    );
  }

  @override
  List<Object?> get props => [
    answers,
    submitting,
    placement,
    usedFallback,
    consentRequired,
  ];
}

class AssessmentController extends Notifier<AssessmentState> {
  @override
  AssessmentState build() => const AssessmentState();

  /// Records the chosen option for a question.
  void record(String questionId, String optionId) {
    state = state.copyWith(answers: {...state.answers, questionId: optionId});
  }

  /// Sends the answers for server-side scoring. Never throws: if the backend
  /// can't be reached the child still gets a journey from the fallback
  /// placement, and the next submission writes the real one (ADR 0003).
  Future<AssessmentPlacement> submit({required String childId}) async {
    state = state.copyWith(submitting: true);
    try {
      final placement = await ref
          .read(assessmentRepositoryProvider)
          .submit(childId: childId, answers: state.answers);
      state = state.copyWith(
        submitting: false,
        placement: placement,
        usedFallback: false,
      );
      return placement;
    } catch (error) {
      debugPrint('assessment submission failed: $error');
      if (isParentConsentFailure(error)) {
        // Do not show the offline fallback as a scored placement. The
        // question screen asks for the current terms and retries.
        state = state.copyWith(submitting: false, consentRequired: true);
        return AssessmentPlacement.fallback;
      }
      state = state.copyWith(
        submitting: false,
        placement: AssessmentPlacement.fallback,
        usedFallback: true,
      );
      return AssessmentPlacement.fallback;
    }
  }

  /// Clears the consent marker after a successful retry.
  void clearConsentRequired() {
    if (state.consentRequired) {
      state = state.copyWith(consentRequired: false);
    }
  }

  void restart() => state = const AssessmentState();
}

final assessmentProvider =
    NotifierProvider<AssessmentController, AssessmentState>(
      AssessmentController.new,
    );
