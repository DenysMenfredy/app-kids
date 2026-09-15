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

class AssessmentIntroScreen extends ConsumerWidget {
  const AssessmentIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childName = ref.watch(childProvider).name;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: FloatingWidget(
                  child: LeleMascot(
                    size: 110,
                    color: AppColors.teal,
                    mouthColor: AppColors.tealDark,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Vamos conhecer\n$childName!',
                textAlign: TextAlign.center,
                style: AppTextStyles.baloo(27, height: 1.25),
              ),
              const SizedBox(height: 16),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 290),
                  child: Text(
                    '3 perguntas rápidas para montarmos a jornada ideal de '
                    'leitura. Sem certo ou errado!',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.nunito(
                      16,
                      color: AppColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.teal,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        'Leva 1 minuto',
                        style: AppTextStyles.nunito(
                          14,
                          weight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
