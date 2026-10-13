import 'dart:async';

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
import '../../../../core/widgets/lele_button.dart';
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
  bool _saving = false;
  bool _saveFailed = false;
  bool _confirmed = false;
  int _wrongAttempts = 0;

  /// The lesson this screen is playing, pinned on first resolve.
  ///
  /// Answering correctly finishes the lesson, which advances
  /// [currentLessonIdProvider] to the next one. Following that here swapped
  /// the celebration for a loading spinner in the second before the reward
  /// screen opens — on Firebase that is a live fetch of a lesson the child
  /// is not playing yet, right at the moment they got the answer right.
  LessonContent? _content;

  Future<void> _onTap(ListenActivity activity, String word) async {
    if (_done) return;
    final correct = word == activity.answer;
    setState(() {
      _picked = word;
      _done = correct;
    });
    final saved = await ref.read(lessonSessionProvider).recordAttempt(
      activity.id,
      {'selectedLabel': word},
    );
    if (!mounted) return;
    if (!saved) {
      setState(() => _done = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível guardar sua resposta. Tente novamente.',
          ),
        ),
      );
      return;
    }
    if (correct) {
      ref.read(lessonStatsProvider.notifier).recordCorrect();
      if (_content?.story != null) {
        unawaited(ref.read(feedbackServiceProvider).play(FeedbackCue.correct));
        unawaited(
          ref.read(ttsServiceProvider).speak('Vamos ler uma história!'),
        );
        await Future<void>.delayed(const Duration(milliseconds: 1000));
        if (mounted) context.goNamed(AppRoutes.activityStory);
      } else {
        await _save();
      }
    } else {
      ref.read(lessonStatsProvider.notifier).recordWrong();
      unawaited(ref.read(feedbackServiceProvider).play(FeedbackCue.wrong));
      setState(() => _wrongAttempts++);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && !_done) setState(() => _picked = null);
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _confirmed) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    final session = ref.read(lessonSessionProvider);
    final reward = await session.complete();
    if (!mounted) return;
    if (reward == null) {
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
      return;
    }
    session.publishReward(reward);
    setState(() {
      _saving = false;
      _confirmed = true;
    });
    unawaited(ref.read(feedbackServiceProvider).play(FeedbackCue.celebrate));
    unawaited(ref.read(ttsServiceProvider).speak('Parabéns!'));
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (mounted) context.goNamed(AppRoutes.reward);
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
      message: _confirmed
          ? 'Parabéns! ★'
          : _saving
          ? 'Salvando...'
          : _saveFailed
          ? 'Ainda não conseguimos salvar.'
          : _done
          ? 'Muito bem! ★'
          : _picked != null
          ? 'Escute de novo!'
          : null,
      messageColor: _done && !_saveFailed ? AppColors.green : AppColors.red,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        activity.instruction,
                        style: AppTextStyles.heading,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PulsingWidget(
                        child: Semantics(
                          button: true,
                          label: 'Ouvir a palavra',
                          excludeSemantics: true,
                          child: GestureDetector(
                            onTap: () => ref
                                .read(ttsServiceProvider)
                                .speak(activity.speech),
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
                      Column(
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
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: CircularProgressIndicator(),
            ),
          if (_saveFailed) ...[
            const Text(
              'Verifique a conexão. Sua conclusão precisa ser confirmada.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            LeleButton(label: 'Tentar salvar novamente', onPressed: _save),
            TextButton(
              onPressed: () => context.goNamed(AppRoutes.lessonIntro),
              child: const Text('Voltar à lição'),
            ),
          ],
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
