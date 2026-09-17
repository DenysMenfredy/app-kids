import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/layout/adaptive_page.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../../../core/widgets/lele_icon_button.dart';
import '../../learning/application/journey_provider.dart';
import '../application/lesson_content_provider.dart';
import '../application/lesson_controller.dart';
import '../application/lesson_session_controller.dart';
import '../domain/lesson.dart';
import 'activity_presentation.dart';

class LessonIntroScreen extends ConsumerWidget {
  const LessonIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(currentLessonContentProvider);
    return Scaffold(
      body: SafeArea(
        child: AdaptiveWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.md,
              AppSpacing.xxl,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: LeleIconButton(
                    icon: Icons.close_rounded,
                    onPressed: () => context.goNamed(AppRoutes.childHome),
                    semanticLabel: 'Sair da lição',
                    alignment: Alignment.centerLeft,
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
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'LIÇÃO $lessonNumber · ${lesson.theme.toUpperCase()}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.eyebrow(AppColors.teal),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  lesson.title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title.copyWith(height: 1.2),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${ActivityType.values.length} atividades · cerca de '
                  '${lesson.estimatedMinutes} minutos',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                for (final type in ActivityType.values) ...[
                  _ActivityRow(presentation: activityPresentation[type]!),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        LeleButton(
          label: 'Começar!',
          height: 60,
          fontSize: 21,
          onPressed: () {
            ref.read(lessonSessionProvider).start();
            ref.read(ttsServiceProvider).speak(lesson.tap.speech);
            context.goNamed(ref.read(lessonFlowProvider).firstRoute);
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
          style: AppTextStyles.heading.copyWith(height: 1.25),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Verifique sua conexão e tente de novo.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.xl),
        TextButton(
          onPressed: onRetry,
          child: Text(
            'Tentar de novo',
            style: AppTextStyles.subheading.copyWith(
              color: AppColors.orangeDark,
            ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Row(
        spacing: AppSpacing.lg,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: presentation.chipColor,
              borderRadius: BorderRadius.circular(AppRadius.field),
            ),
            child: Icon(presentation.icon, size: 22, color: Colors.white),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(presentation.title, style: AppTextStyles.sectionTitle),
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
