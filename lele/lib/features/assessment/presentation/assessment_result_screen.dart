import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../../../core/widgets/lele_mascot.dart';
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
    final result = ref.watch(
          assessmentProvider.select((s) => s.placement),
        ) ??
        AssessmentPlacement.fallback;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
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
                    child: const Icon(Icons.star_rounded,
                        size: 52, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Jornada pronta!',
                textAlign: TextAlign.center,
                style: AppTextStyles.baloo(27, height: 1.25),
              ),
              const SizedBox(height: 10),
              Text(
                'Com base nas respostas, $childName vai começar em:',
                textAlign: TextAlign.center,
                style: AppTextStyles.nunito(
                  16,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border, width: 2),
                ),
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
                    const SizedBox(height: 8),
                    Text(result.moduleTitle, style: AppTextStyles.baloo(22)),
                    const SizedBox(height: 8),
                    Text(
                      result.description,
                      style: AppTextStyles.nunito(
                        14,
                        color: AppColors.textMuted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      spacing: 8,
                      children: [
                        for (final tag in result.tags)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.panel,
                              borderRadius: BorderRadius.circular(10),
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
              const SizedBox(height: 22),
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
