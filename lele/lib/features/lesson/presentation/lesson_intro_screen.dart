import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/layout/adaptive_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../../learning/application/journey_provider.dart';
import '../application/lesson_controller.dart';
import '../application/lesson_stats_controller.dart';
import '../data/lesson_repository.dart';
import '../data/lesson_sync_service.dart';
import '../domain/lesson.dart';

class LessonIntroScreen extends ConsumerWidget {
  const LessonIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(currentLessonContentProvider);
    return Scaffold(
      body: SafeArea(
        child: AdaptiveWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 12, 26, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => context.goNamed(AppRoutes.childHome),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.panel,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: content.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.teal),
                    ),
                    error: (error, _) => _LoadFailed(
                      onRetry: () => ref.invalidate(
                        lessonContentProvider(
                          ref.read(currentLessonIdProvider),
                        ),
                      ),
                    ),
                    data: (lesson) => _Lesson(lesson: lesson),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Lesson extends ConsumerWidget {
  const _Lesson({required this.lesson});

  final LessonContent lesson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonNumber = ref.watch(currentLessonNumberProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The lesson summary scrolls; "Começar!" stays on screen at every
        // size. A child should never have to hunt for the button that
        // starts the lesson — on a 320px phone it used to sit 515px below
        // the fold with nothing to scroll.
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text(
                  'LIÇÃO $lessonNumber · ${lesson.theme.toUpperCase()}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.eyebrow(AppColors.teal),
                ),
                const SizedBox(height: 8),
                Text(
                  lesson.title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.baloo(28, height: 1.2),
                ),
                const SizedBox(height: 8),
                Text(
                  '${ActivityType.values.length} atividades · cerca de '
                  '${lesson.estimatedMinutes} minutos',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.nunito(15, color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                for (final type in ActivityType.values) ...[
                  _ActivityRow(presentation: activityPresentation[type]!),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        LeleButton(
          label: 'Começar!',
          height: 60,
          fontSize: 21,
          onPressed: () {
            final flow = ref.read(lessonFlowProvider);
            ref.read(lessonStatsProvider.notifier).start();
            ref
                .read(lessonSyncServiceProvider)
                .lessonStarted(ref.read(currentLessonIdProvider));
            ref.read(ttsServiceProvider).speak(lesson.tap.speech);
            context.goNamed(flow.firstRoute);
          },
        ),
      ],
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Não conseguimos carregar a lição',
          textAlign: TextAlign.center,
          style: AppTextStyles.baloo(22, height: 1.25),
        ),
        const SizedBox(height: 10),
        Text(
          'Verifique sua conexão e tente de novo.',
          textAlign: TextAlign.center,
          style: AppTextStyles.nunito(15, color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: onRetry,
          child: Text(
            'Tentar de novo',
            style: AppTextStyles.baloo(18, color: AppColors.orangeDark),
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.presentation});

  final ActivityPresentation presentation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Row(
        spacing: 14,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: presentation.chipColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(presentation.icon, size: 22, color: Colors.white),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(presentation.title, style: AppTextStyles.baloo(16)),
                Text(
                  presentation.subtitle,
                  style: AppTextStyles.nunito(
                    12,
                    weight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            presentation.duration,
            style: AppTextStyles.nunito(
              12,
              weight: FontWeight.w700,
              color: AppColors.textFaint,
            ),
          ),
        ],
      ),
    );
  }
}
