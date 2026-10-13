import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/activity_scaffold.dart';
import '../../../../core/widgets/lele_button.dart';
import '../../../../core/widgets/lele_card.dart';
import '../../../learning/application/journey_provider.dart';
import '../../application/lesson_content_provider.dart';
import '../../application/story_controller.dart';
import '../../domain/story.dart';
import '../widgets/story_page_card.dart';

class StoryActivityScreen extends ConsumerStatefulWidget {
  const StoryActivityScreen({super.key});
  @override
  ConsumerState<StoryActivityScreen> createState() =>
      _StoryActivityScreenState();
}

class _StoryActivityScreenState extends ConsumerState<StoryActivityScreen> {
  StoryActivity? _story;
  @override
  Widget build(BuildContext context) {
    final content = ref.watch(currentLessonContentProvider);
    final story = _story ??= content.value?.story;
    if (story != null) return StoryPlayer(story: story);
    return ActivityScaffold(
      progress: 0,
      onClose: () => context.goNamed(AppRoutes.childHome),
      child: Center(
        child: content.isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    content.hasError
                        ? 'Não foi possível abrir a história.'
                        : 'Esta lição não contém história.',
                    textAlign: TextAlign.center,
                  ),
                  if (content.hasError)
                    TextButton(
                      onPressed: () => ref.invalidate(
                        lessonContentProvider(
                          ref.read(currentLessonIdProvider),
                        ),
                      ),
                      child: const Text('Tentar novamente'),
                    ),
                ],
              ),
      ),
    );
  }
}

class StoryPlayer extends ConsumerWidget {
  const StoryPlayer({super.key, required this.story});
  final StoryActivity story;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = storyControllerProvider(story);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen(provider, (_, next) {
      if (next.phase == StoryPhase.finished) context.goNamed(AppRoutes.reward);
    });
    final reading = state.phase == StoryPhase.reading;
    final question = story.questions[state.questionIndex];
    final saving = state.phase == StoryPhase.saving;
    final failed = state.phase == StoryPhase.failed;
    return ActivityScaffold(
      progress: reading
          ? .8 + .1 * (state.pageIndex + 1) / story.pages.length
          : .9 + .1 * (state.questionIndex + 1) / story.questions.length,
      onClose: () => context.goNamed(AppRoutes.childHome),
      message: failed
          ? 'Não foi possível salvar.'
          : state.picked == null
          ? null
          : state.correct
          ? 'Muito bem! ★'
          : 'Vamos tentar de novo!',
      messageColor: state.correct ? AppColors.green : AppColors.red,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  if (failed)
                    const Text(
                      'Ainda não conseguimos salvar. Verifique a conexão e tente novamente.',
                      textAlign: TextAlign.center,
                    ),
                  Text(
                    story.title,
                    style: AppTextStyles.heading,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    reading
                        ? 'Página ${state.pageIndex + 1} de ${story.pages.length}'
                        : 'Pergunta ${state.questionIndex + 1} de ${story.questions.length}',
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  TextButton.icon(
                    onPressed: saving || failed ? null : controller.narrate,
                    icon: const Icon(Icons.volume_up_rounded),
                    label: Text(
                      reading ? 'Ouvir a página' : 'Ouvir a pergunta',
                    ),
                  ),
                  if (reading)
                    StoryPageCard(page: story.pages[state.pageIndex])
                  else ...[
                    Text(
                      question.prompt,
                      style: AppTextStyles.subheading,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    for (final option in question.options) ...[
                      LeleCard(
                        onTap: saving || failed || state.correct
                            ? null
                            : () => controller.answer(option),
                        color: state.picked == option
                            ? (state.correct
                                  ? AppColors.green
                                  : AppColors.redPale)
                            : AppColors.surface,
                        child: Text(
                          option,
                          style: AppTextStyles.subheading,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (reading && state.pageIndex > 0)
            TextButton(
              onPressed: controller.previousPage,
              child: const Text('Página anterior'),
            ),
          LeleButton(
            label: failed
                ? 'Tentar salvar novamente'
                : reading
                ? (state.pageIndex == story.pages.length - 1
                      ? 'Responder perguntas'
                      : 'Próxima página')
                : saving
                ? 'Salvando...'
                : state.questionIndex == story.questions.length - 1
                ? 'Concluir história'
                : 'Próxima pergunta',
            enabled: failed || reading || (!saving && state.correct),
            onPressed: reading
                ? controller.nextPage
                : controller.continueAfterAnswer,
          ),
          if (failed)
            TextButton(
              onPressed: () => context.goNamed(AppRoutes.lessonIntro),
              child: const Text('Voltar à lição'),
            ),
        ],
      ),
    );
  }
}
