import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/layout/adaptive_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../../../core/widgets/lele_card.dart';
import '../../../core/widgets/motion.dart';
import '../../session/application/child_provider.dart';
import '../application/assessment_controller.dart';
import '../domain/assessment.dart';

class AssessmentResultScreen extends ConsumerWidget {
  const AssessmentResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childName = ref.watch(childProvider).name;
    // Placement decided by the backend; the fallback only appears when the
    // submission couldn't reach it (ADR 0003).
    final result =
        ref.watch(assessmentProvider.select((s) => s.placement)) ??
        AssessmentPlacement.fallback;

    return Scaffold(
      body: SafeArea(
        child: AdaptivePage(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xxl,
            AppSpacing.xxl,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: PopIn(
                  child: Container(
                    width: 90,
                    height: 90,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.yellow,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.yellowDark,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      size: 52,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Jornada pronta!',
                textAlign: TextAlign.center,
                style: AppTextStyles.title.copyWith(height: 1.25),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Com base nas respostas, $childName vai começar em:',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              LeleCard(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                borderRadius: AppRadius.panel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MÓDULO ${result.moduleNumber}',
                      style: AppTextStyles.nunito(
                        12,
                        weight: FontWeight.w700,
                        color: AppColors.teal,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(result.moduleTitle, style: AppTextStyles.heading),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      result.description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Wrap, not Row: three tags fit on a wide phone and
                    // need a second line on a narrow one.
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final tag in result.tags)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.panel,
                              borderRadius: BorderRadius.circular(
                                AppRadius.chip,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: AppTextStyles.nunito(
                                12,
                                weight: FontWeight.w700,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              LeleButton(
                label: 'Ir para o painel',
                onPressed: () => context.goNamed(AppRoutes.dashboard),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
