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
import '../../../core/widgets/lele_mascot.dart';
import '../../../core/widgets/motion.dart';
import '../../session/application/child_provider.dart';
import '../application/assessment_controller.dart';

class AssessmentIntroScreen extends ConsumerWidget {
  const AssessmentIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childName = ref.watch(childProvider).name;
    return Scaffold(
      body: SafeArea(
        child: AdaptivePage(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: FloatingWidget(
                  child: LeleMascot(
                    semanticLabel: 'O mascote Lelê',
                    size: 110,
                    color: AppColors.teal,
                    mouthColor: AppColors.tealDark,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Vamos conhecer\n$childName!',
                textAlign: TextAlign.center,
                style: AppTextStyles.title.copyWith(height: 1.25),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 290),
                  child: Text(
                    '3 perguntas rápidas para montarmos a jornada ideal de '
                    'leitura. Sem certo ou errado!',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: AppSpacing.sm,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.teal,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          'Leva 1 minuto',
                          maxLines: 1,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              LeleButton(
                label: 'Vamos lá',
                color: AppColors.teal,
                shadowColor: AppColors.tealDark,
                onPressed: () {
                  ref.read(assessmentProvider.notifier).restart();
                  context.goNamed(AppRoutes.assessmentQuestions);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
