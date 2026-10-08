import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/audio/feedback_cues.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/activity_scaffold.dart';
import '../../../../core/widgets/motion.dart';
import '../../../learning/application/journey_provider.dart';
import '../../application/lesson_content_provider.dart';
import '../../application/lesson_controller.dart';
import '../../application/lesson_session_controller.dart';
import '../../application/lesson_stats_controller.dart';
import '../../domain/lesson.dart';

class ListenActivityScreen extends ConsumerStatefulWidget {
  const ListenActivityScreen({super.key});

  @override
  ConsumerState<ListenActivityScreen> createState() =>
      _ListenActivityScreenState();
}

class _ListenActivityScreenState extends ConsumerState<ListenActivityScreen> {
  String? _picked;
  bool _done = false;
  int _wrongAttempts = 0;

  /// The lesson this screen is playing, pinned on first resolve.
  ///
  /// Answering correctly finishes the lesson, which advances
  /// [currentLessonIdProvider] to the next one. Following that here swapped
  /// the celebration for a loading spinner in the second before the reward
  /// screen opens — on Firebase that is a live fetch of a lesson the child
  /// is not playing yet, right at the moment they got the answer right.
  LessonContent? _content;

  void _onTap(ListenActivity activity, String word) {
    if (_done) return;
    if (word == activity.answer) {
      ref.read(lessonStatsProvider.notifier).recordCorrect();
      ref.read(lessonSessionProvider).recordAttempt(activity.id, {
        'selectedLabel': word,
      });
      // The last answer of the lesson: the bigger cue.
      ref.read(feedbackServiceProvider).play(FeedbackCue.celebrate);
      ref.read(ttsServiceProvider).speak('Parabéns!');
      setState(() {
        _picked = word;
        _done = true;
      });
      // Reported right away rather than on the reward screen: the
      // celebration animation is what covers the round trip.
      final session = ref.read(lessonSessionProvider);
      final rewardFuture = session.complete();

      Future.delayed(const Duration(milliseconds: 1000), () async {
        final reward = await rewardFuture;
        if (!mounted) return;
        session.publishReward(reward);
        context.goNamed(
          ref.read(lessonFlowProvider).nextRoute(ActivityType.listen),
        );
      });
    } else {
      ref.read(lessonStatsProvider.notifier).recordWrong();
      ref.read(lessonSessionProvider).recordAttempt(activity.id, {
        'selectedLabel': word,
      });
      // This activity said nothing at all on a wrong word before.
      ref.read(feedbackServiceProvider).play(FeedbackCue.wrong);
      setState(() {
        _picked = word;
        _wrongAttempts++;
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && !_done) setState(() => _picked = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watched every build so the subscription stays live; pinned once it
    // first resolves.
    final resolved = ref.watch(currentLessonContentProvider).value;
    final content = _content ??= resolved;
    if (content == null) return const ActivityLoading();
    final activity = content.listen;
    final flow = ref.watch(lessonFlowProvider);
    return ActivityScaffold(
      progress: flow.progressOf(ActivityType.listen),
      onClose: () => context.goNamed(AppRoutes.childHome),
      message: _done
          ? 'Parabéns! ★'
          : _picked != null
          ? 'Escute de novo!'
          : null,
      messageColor: _done ? AppColors.green : AppColors.red,
      scrollableContent: true,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          Text(activity.instruction, style: AppTextStyles.heading),
          const SizedBox(height: AppSpacing.lg),
          PulsingWidget(
            child: Semantics(
              button: true,
              label: 'Ouvir a palavra',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () =>
                    ref.read(ttsServiceProvider).speak(activity.speech),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(
                    color: AppColors.purple,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.purpleDark,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.volume_up_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                      Text(
                        'ouvir',
                        style: AppTextStyles.micro.copyWith(
                          color: AppColors.purpleText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final word in activity.options) ...[
                  _WordCard(
                    word: word,
                    picked: _picked == word,
                    correct: word == activity.answer,
                    wrongAttempts: _wrongAttempts,
                    onTap: () => _onTap(activity, word),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({
    required this.word,
    required this.picked,
    required this.correct,
    required this.wrongAttempts,
    required this.onTap,
  });

  final String word;
  final bool picked;
  final bool correct;
  final int wrongAttempts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRight = picked && correct;
    final isWrong = picked && !correct;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 70,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isRight ? AppColors.green : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isRight
              ? AppColors.greenDark
              : isWrong
              ? AppColors.red
              : AppColors.border,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: isRight ? AppColors.greenDark : AppColors.border,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        word,
        style: AppTextStyles.wordGlyph.copyWith(
          color: isRight
              ? Colors.white
              : isWrong
              ? AppColors.red
              : AppColors.textDark,
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: picked,
      label: word,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: BurstOverlay(
          trigger: isRight ? word : null,
          colors: AppColors.celebration,
          child: isRight
              ? PopIn(child: card)
              : ShakeWidget(
                  trigger: isWrong ? wrongAttempts : null,
                  child: card,
                ),
        ),
      ),
    );
  }
}
