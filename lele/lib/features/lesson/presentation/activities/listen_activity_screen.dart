import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/activity_scaffold.dart';
import '../../../../core/widgets/lele_mascot.dart';
import '../../application/lesson_controller.dart';
import '../../application/lesson_stats_controller.dart';
import '../../data/lesson_sync_service.dart';
import '../../domain/lesson.dart';
import '../../../session/application/session_controller.dart';

const _answer = 'BOLA';
const _words = ['GATO', 'BOLA', 'CASA'];

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

  void _onTap(String word) {
    if (_done) return;
    if (word == _answer) {
      ref.read(lessonStatsProvider.notifier).recordCorrect();
      ref.read(ttsServiceProvider).speak('Parabéns!');
      setState(() {
        _picked = word;
        _done = true;
      });
      // Report the finished lesson right away; the backend decides the
      // reward (ADR 0003). The celebration animation covers the round trip,
      // and a slow network can't hold the child on this screen.
      final stats = ref.read(lessonStatsProvider);
      final rewardFuture = ref
          .read(lessonSyncServiceProvider)
          .lessonCompleted(
            todaysLessonId,
            durationSeconds: stats.durationSeconds(DateTime.now()),
            score: stats.score,
            attempts: stats.attempts,
            correctAnswers: stats.correctAnswers,
            wrongAnswers: stats.wrongAnswers,
          )
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      // Demo mode only — a no-op once the backend owns the totals.
      ref.read(sessionProvider.notifier).completeLesson();

      Future.delayed(const Duration(milliseconds: 1000), () async {
        final reward = await rewardFuture;
        if (!mounted) return;
        ref.read(lastLessonRewardProvider.notifier).set(reward);
        context.goNamed(
          ref.read(lessonFlowProvider).nextRoute(ActivityType.listen),
        );
      });
    } else {
      ref.read(lessonStatsProvider.notifier).recordWrong();
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
      child: Column(
        children: [
          const SizedBox(height: 18),
          Text('Qual palavra você ouviu?', style: AppTextStyles.baloo(23)),
          const SizedBox(height: 16),
          PulsingWidget(
            child: GestureDetector(
              onTap: () => ref.read(ttsServiceProvider).speak('bola'),
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
                    const Icon(Icons.volume_up_rounded,
                        size: 40, color: Colors.white),
                    Text(
                      'ouvir',
                      style: AppTextStyles.baloo(
                        13,
                        color: AppColors.purpleText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final word in _words) ...[
                  _WordCard(
                    word: word,
                    picked: _picked == word,
                    correct: word == _answer,
                    wrongAttempts: _wrongAttempts,
                    onTap: () => _onTap(word),
                  ),
                  const SizedBox(height: 12),
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
        borderRadius: BorderRadius.circular(22),
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
        style: AppTextStyles.baloo(
          28,
          color: isRight
              ? Colors.white
              : isWrong
                  ? AppColors.red
                  : AppColors.textDark,
          letterSpacing: 3.4,
        ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: isRight
          ? PopIn(child: card)
          : ShakeWidget(
              trigger: isWrong ? wrongAttempts : null,
              child: card,
            ),
    );
  }
}
