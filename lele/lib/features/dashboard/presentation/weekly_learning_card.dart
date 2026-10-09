import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_card.dart';
import '../application/weekly_learning_provider.dart';
import '../domain/learning_week.dart';

class WeeklyLearningCard extends ConsumerWidget {
  const WeeklyLearningCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(weeklyLearningProvider);
    return LeleCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      borderRadius: AppRadius.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Esta semana', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.lg),
          if (state.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (state.hasError)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Não conseguimos atualizar a semana.'),
                TextButton.icon(
                  onPressed: () => ref.invalidate(weeklyLearningQueryProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            )
          else
            _WeekChart(week: state.requireValue),
        ],
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.week});
  final LearningWeek week;
  @override
  Widget build(BuildContext context) {
    const labels = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
    final maximum = week.days.fold<int>(
      1,
      (maximum, day) =>
          day.activeSeconds > maximum ? day.activeSeconds : maximum,
    );
    final minutes = week.activeSeconds ~/ 60;
    final time = week.activeSeconds > 0 && minutes == 0
        ? 'menos de 1 min'
        : '$minutes min';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: AppSpacing.md,
          children: [
            for (var i = 0; i < week.days.length; i++)
              Expanded(
                child: Semantics(
                  label:
                      '${week.days[i].localDate}: ${week.days[i].activeSeconds} segundos de prática',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 66,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height:
                                6 + 60 * week.days[i].activeSeconds / maximum,
                            decoration: BoxDecoration(
                              color: week.days[i].activeSeconds == 0
                                  ? AppColors.panel
                                  : week.days[i].localDate == week.today
                                  ? AppColors.orange
                                  : AppColors.teal,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        labels[i],
                        style: AppTextStyles.nunito(
                          11,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (week.sessionsCompleted == 0)
          Text(
          'Seu resumo aparece após a próxima prática concluída.',
            style: AppTextStyles.bodySmall,
          )
        else ...[
          Text(
            '${week.lessonsCompleted} lições novas · $time de prática',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          if (week.accuracy != null)
            Text(
              '${week.accuracy}% de acertos nas atividades',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          Text(
            'Hoje: ${week.todayLessons}/${week.dailyGoalLessons} lição nova',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}
