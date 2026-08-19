import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../application/lesson_controller.dart';
import '../application/lesson_stats_controller.dart';
import '../data/lesson_sync_service.dart';
import '../domain/lesson.dart';

class LessonIntroScreen extends ConsumerWidget {
  const LessonIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
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
                    child: const Icon(Icons.close_rounded,
                        size: 22, color: AppColors.textMuted),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'LIÇÃO 8 · SONS E RIMAS',
                textAlign: TextAlign.center,
                style: AppTextStyles.eyebrow(AppColors.teal),
              ),
              const SizedBox(height: 8),
              Text(
                'Vamos brincar com as letras!',
                textAlign: TextAlign.center,
                style: AppTextStyles.baloo(28, height: 1.2),
              ),
              const SizedBox(height: 8),
              Text(
                '4 atividades · cerca de 15 minutos',
                textAlign: TextAlign.center,
                style: AppTextStyles.nunito(15, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              for (final activity in todaysLesson) ...[
                _ActivityRow(activity: activity),
                const SizedBox(height: 10),
              ],
              const Spacer(),
              LeleButton(
                label: 'Começar!',
                height: 60,
                fontSize: 21,
                onPressed: () {
                  final flow = ref.read(lessonFlowProvider);
                  ref.read(lessonStatsProvider.notifier).start();
                  ref
                      .read(lessonSyncServiceProvider)
                      .lessonStarted(todaysLessonId);
                  ref
                      .read(ttsServiceProvider)
                      .speak('Toque na letra Bê');
                  context.goNamed(flow.firstRoute);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final LessonActivity activity;

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
              color: activity.chipColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(activity.icon, size: 22, color: Colors.white),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.title, style: AppTextStyles.baloo(16)),
                Text(
                  activity.subtitle,
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
            activity.duration,
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
