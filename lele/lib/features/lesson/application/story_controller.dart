import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/feedback_cues.dart';
import '../../../core/services/feedback_service.dart';
import '../../../core/services/tts_service.dart';
import '../domain/story.dart';
import 'lesson_session_controller.dart';
import 'lesson_stats_controller.dart';

enum StoryPhase { reading, questions, saving, failed, finished }

class StoryState {
  const StoryState({
    this.phase = StoryPhase.reading,
    this.pageIndex = 0,
    this.questionIndex = 0,
    this.picked,
    this.correct = false,
  });
  final StoryPhase phase;
  final int pageIndex;
  final int questionIndex;
  final String? picked;
  final bool correct;
}

class StoryController extends Notifier<StoryState> {
  StoryController(this.story);
  final StoryActivity story;
  final _answered = <String>{};

  @override
  StoryState build() {
    final tts = ref.read(ttsServiceProvider);
    ref.onDispose(() => unawaited(tts.stop()));
    _answered.addAll(
      ref.read(lessonRunProvider)?.completedItems[story.id] ?? const <String>{},
    );
    if (_answered.isNotEmpty) {
      final index = story.questions.indexWhere(
        (question) => !_answered.contains(question.id),
      );
      return StoryState(
        phase: StoryPhase.questions,
        questionIndex: index < 0 ? story.questions.length - 1 : index,
        correct: index < 0,
      );
    }
    return const StoryState();
  }

  void narrate() {
    final text = state.phase == StoryPhase.reading
        ? story.pages[state.pageIndex].text
        : story.questions[state.questionIndex].prompt;
    unawaited(ref.read(ttsServiceProvider).speak(text));
  }

  void previousPage() {
    if (state.phase != StoryPhase.reading || state.pageIndex == 0) return;
    unawaited(ref.read(ttsServiceProvider).stop());
    state = StoryState(pageIndex: state.pageIndex - 1);
  }

  void nextPage() {
    if (state.phase != StoryPhase.reading) return;
    unawaited(ref.read(ttsServiceProvider).stop());
    state = state.pageIndex == story.pages.length - 1
        ? const StoryState(phase: StoryPhase.questions)
        : StoryState(pageIndex: state.pageIndex + 1);
  }

  void answer(String label) {
    if (state.phase != StoryPhase.questions || state.correct) return;
    final question = story.questions[state.questionIndex];
    if (!question.options.contains(label)) return;
    final correct = label == question.answer;
    ref.read(lessonSessionProvider).recordAttempt(story.id, {
      'questionId': question.id,
      'selectedLabel': label,
    });
    final stats = ref.read(lessonStatsProvider.notifier);
    if (correct) {
      stats.recordCorrect();
    } else {
      stats.recordWrong();
    }
    unawaited(
      ref
          .read(feedbackServiceProvider)
          .play(correct ? FeedbackCue.correct : FeedbackCue.wrong),
    );
    state = StoryState(
      phase: StoryPhase.questions,
      pageIndex: state.pageIndex,
      questionIndex: state.questionIndex,
      picked: label,
      correct: correct,
    );
  }

  Future<void> continueAfterAnswer() async {
    if (![StoryPhase.questions, StoryPhase.failed].contains(state.phase) ||
        !state.correct) {
      return;
    }
    unawaited(ref.read(ttsServiceProvider).stop());
    final session = ref.read(lessonSessionProvider);
    final index = state.questionIndex;
    state = StoryState(
      phase: StoryPhase.saving,
      questionIndex: index,
      correct: true,
    );
    if (!await session.persistAttempts()) {
      if (ref.mounted) {
        state = StoryState(
          phase: StoryPhase.failed,
          questionIndex: index,
          correct: true,
        );
      }
      return;
    }
    if (!ref.mounted) return;
    _answered.add(story.questions[index].id);
    final nextIndex = story.questions.indexWhere(
      (question) => !_answered.contains(question.id),
    );
    if (nextIndex >= 0) {
      state = StoryState(phase: StoryPhase.questions, questionIndex: nextIndex);
      return;
    }
    state = StoryState(
      phase: StoryPhase.saving,
      questionIndex: state.questionIndex,
    );
    final reward = await session.complete();
    if (!ref.mounted) return;
    if (reward == null) {
      state = StoryState(
        phase: StoryPhase.failed,
        questionIndex: state.questionIndex,
        correct: true,
      );
      return;
    }
    session.publishReward(reward);
    unawaited(ref.read(feedbackServiceProvider).play(FeedbackCue.celebrate));
    state = const StoryState(phase: StoryPhase.finished);
  }
}

final storyControllerProvider = NotifierProvider.autoDispose
    .family<StoryController, StoryState, StoryActivity>(StoryController.new);
