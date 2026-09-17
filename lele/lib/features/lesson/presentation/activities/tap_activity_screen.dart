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
import '../../application/lesson_content_provider.dart';
import '../../application/lesson_controller.dart';
import '../../application/lesson_stats_controller.dart';
import '../../domain/lesson.dart';
import '../widgets/highlighted_instruction.dart';

class TapActivityScreen extends ConsumerStatefulWidget {
  const TapActivityScreen({super.key});

  @override
  ConsumerState<TapActivityScreen> createState() => _TapActivityScreenState();
}

class _TapActivityScreenState extends ConsumerState<TapActivityScreen> {
  String? _picked;
  bool _done = false;
  int _wrongAttempts = 0;

  void _onTap(TapActivity activity, String letter) {
    if (_done) return;
    final tts = ref.read(ttsServiceProvider);
    final feedback = ref.read(feedbackServiceProvider);
    final stats = ref.read(lessonStatsProvider.notifier);
    if (letter == activity.target) {
      stats.recordCorrect();
      feedback.play(FeedbackCue.correct);
      tts.speak('Muito bem!');
      setState(() {
        _picked = letter;
        _done = true;
      });
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) {
          context.goNamed(
            ref.read(lessonFlowProvider).nextRoute(ActivityType.tap),
          );
        }
      });
    } else {
      stats.recordWrong();
      // Sound first: it lands before the spoken prompt has finished its
      // first syllable, which is what makes a miss unmistakable.
      feedback.play(FeedbackCue.wrong);
      tts.speak('Tente de novo');
      setState(() {
        _picked = letter;
        _wrongAttempts++;
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && !_done) setState(() => _picked = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(currentLessonContentProvider).value;
    if (content == null) return const ActivityLoading();
    final activity = content.tap;
    final flow = ref.watch(lessonFlowProvider);
    return ActivityScaffold(
      progress: flow.progressOf(ActivityType.tap),
      onClose: () => context.goNamed(AppRoutes.childHome),
      message: _done
          ? 'Muito bem! ★'
          : _picked != null
          ? 'Quase! Tente de novo'
          : null,
      messageColor: _done ? AppColors.green : AppColors.red,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: AppSpacing.md,
            children: [
              _SpeakButton(
                onTap: () =>
                    ref.read(ttsServiceProvider).speak(activity.speech),
              ),
              Flexible(
                child: HighlightedInstruction(
                  instruction: activity.instruction,
                  token: activity.target,
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.lg,
                crossAxisSpacing: AppSpacing.lg,
                childAspectRatio: 1.35,
                children: [
                  for (final letter in activity.options)
                    _LetterCard(
                      letter: letter,
                      picked: _picked == letter,
                      correct: letter == activity.target,
                      wrongAttempts: _wrongAttempts,
                      onTap: () => _onTap(activity, letter),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeakButton extends StatelessWidget {
  const _SpeakButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ouvir o som da letra',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.teal,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: AppColors.tealDark, offset: Offset(0, 4)),
            ],
          ),
          child: const Icon(
            Icons.volume_up_rounded,
            size: 26,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _LetterCard extends StatelessWidget {
  const _LetterCard({
    required this.letter,
    required this.picked,
    required this.correct,
    required this.wrongAttempts,
    required this.onTap,
  });

  final String letter;
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
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isRight ? AppColors.green : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.panel),
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
            color: isRight
                ? AppColors.greenDark
                : isWrong
                ? AppColors.redPale
                : AppColors.border,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        letter,
        style: AppTextStyles.letterGlyph.copyWith(
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
      label: 'Letra $letter',
      // The glyph is already the label; without this the card announces
      // itself twice.
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: BurstOverlay(
          trigger: isRight ? letter : null,
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
