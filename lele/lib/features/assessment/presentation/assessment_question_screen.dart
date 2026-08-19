import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../session/application/session_controller.dart';
import '../application/assessment_controller.dart';
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
    final assessment = ref.watch(assessmentProvider);
    final childName = ref.watch(sessionProvider.select((s) => s.child.name));
    final question = assessment.currentQuestion;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                spacing: 8,
                children: [
                  for (var i = 0; i < assessmentQuestions.length; i++)
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: i <= assessment.step
                              ? AppColors.teal
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'PERGUNTA ${assessment.step + 1} DE '
                '${assessmentQuestions.length}',
                style: AppTextStyles.eyebrow(AppColors.textFaint),
              ),
              const SizedBox(height: 12),
              Text(
                question.questionFor(childName),
                style: AppTextStyles.baloo(24, height: 1.3),
              ),
              const SizedBox(height: 24),
              for (var i = 0; i < question.options.length; i++) ...[
                _OptionCard(
                  label: question.options[i],
                  chipColor: _optionChipColors[i % _optionChipColors.length],
                  onTap: () {
                    final done =
                        ref.read(assessmentProvider.notifier).answer(i);
                    if (done) {
                      context.goNamed(AppRoutes.assessmentResult);
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
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
  final VoidCallback onTap;

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
