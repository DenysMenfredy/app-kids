import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../session/application/child_provider.dart';
import '../application/assessment_controller.dart';
import '../data/assessment_repository.dart';
import '../domain/assessment.dart';

const _optionChipColors = [
  AppColors.orangeSoft,
  AppColors.teal,
  AppColors.purple,
];

class AssessmentQuestionScreen extends ConsumerWidget {
  const AssessmentQuestionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(assessmentContentProvider);
    return Scaffold(
      body: SafeArea(
        child: content.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.teal),
          ),
          error: (error, _) => _LoadFailed(
            onRetry: () => ref.invalidate(assessmentContentProvider),
          ),
          data: (assessment) => _Questions(assessment: assessment),
        ),
      ),
    );
  }
}

class _Questions extends ConsumerWidget {
  const _Questions({required this.assessment});

  final Assessment assessment;

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    AssessmentQuestion question,
    String optionId,
  ) async {
    final controller = ref.read(assessmentProvider.notifier);
    controller.record(question.id, optionId);

    final answered = ref.read(assessmentProvider).answers.length;
    if (answered < assessment.questions.length) return;

    await controller.submit(childId: AppConfig.primaryChildId);
    if (context.mounted) context.goNamed(AppRoutes.assessmentResult);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assessmentProvider);
    final childName = ref.watch(childProvider).name;
    final total = assessment.questions.length;
    final index = state.step.clamp(0, total - 1);
    final question = assessment.questions[index];

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                spacing: 8,
                children: [
                  for (var i = 0; i < total; i++)
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: i <= index ? AppColors.teal : AppColors.border,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'PERGUNTA ${index + 1} DE $total',
                style: AppTextStyles.eyebrow(AppColors.textFaint),
              ),
              const SizedBox(height: 12),
              Text(
                question.promptFor(childName),
                style: AppTextStyles.baloo(24, height: 1.3),
              ),
              const SizedBox(height: 24),
              for (var i = 0; i < question.options.length; i++) ...[
                _OptionCard(
                  label: question.options[i].label,
                  chipColor: _optionChipColors[i % _optionChipColors.length],
                  onTap: state.submitting
                      ? null
                      : () => _choose(
                            context,
                            ref,
                            question,
                            question.options[i].id,
                          ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        if (state.submitting)
          const ColoredBox(
            color: Color(0x66FDF6EC),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            ),
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
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Não conseguimos carregar a avaliação',
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
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.chipColor,
    required this.onTap,
  });

  final String label;
  final Color chipColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 2),
        ),
        child: Row(
          spacing: 14,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.nunito(
                  16,
                  weight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
