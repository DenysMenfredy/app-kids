import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../../../core/widgets/lele_mascot.dart';
import '../../learning/domain/learning_module.dart';
import '../../session/application/session_controller.dart';

class _DayActivity {
  const _DayActivity(this.label, this.minutes);

  final String label;
  final int minutes; // 0 = no practice that day
}

/// Weekly practice snapshot; replaced by real analytics later.
const _week = [
  _DayActivity('S', 11),
  _DayActivity('T', 16),
  _DayActivity('Q', 0),
  _DayActivity('Q', 13),
  _DayActivity('S', 20),
  _DayActivity('S', 8),
  _DayActivity('D', 0),
];

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final currentModule = learningJourney.firstWhere(
      (m) => m.status == ModuleStatus.current,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Painel dos pais',
                                style: AppTextStyles.nunito(
                                  14,
                                  color: AppColors.textFaint,
                                ),
                              ),
                              Text(
                                'Olá, ${session.parentName}',
                                style: AppTextStyles.baloo(26),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.goNamed(AppRoutes.paywall),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.purplePale,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              'Teste grátis · 5 dias',
                              style: AppTextStyles.baloo(
                                13,
                                color: AppColors.purple,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _ChildCard(
                      childName: session.child.name,
                      childAge: session.child.age,
                      streak: session.streak,
                      moduleTitle: currentModule.title,
                      progress: currentModule.progress,
                    ),
                    const SizedBox(height: 16),
                    const _WeekCard(),
                    const SizedBox(height: 16),
                    Text('Jornada de aprendizado',
                        style: AppTextStyles.sectionTitle),
                    const SizedBox(height: 10),
                    for (final module in learningJourney) ...[
                      _ModuleRow(module: module),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
              child: SizedBox(
                width: double.infinity,
                child: LeleButton(
                  label: 'Entrar no modo criança',
                  fontSize: 19,
                  onPressed: () => context.goNamed(AppRoutes.childHome),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({
    required this.childName,
    required this.childAge,
    required this.streak,
    required this.moduleTitle,
    required this.progress,
  });

  final String childName;
  final int childAge;
  final int streak;
  final String moduleTitle;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Column(
        children: [
          Row(
            spacing: 14,
            children: [
              const LeleMascot(size: 54, color: AppColors.orangeSoft),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$childName · $childAge anos',
                      style: AppTextStyles.baloo(19),
                    ),
                    Text(
                      '$moduleTitle · Semana 2',
                      style: AppTextStyles.nunito(
                        13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                spacing: 4,
                children: [
                  const Icon(Icons.bolt_rounded,
                      size: 18, color: AppColors.orangeDark),
                  Text(
                    '$streak',
                    style: AppTextStyles.baloo(
                      15,
                      color: AppColors.orangeDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progresso do módulo',
                style: AppTextStyles.nunito(
                  13,
                  weight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                '$percent%',
                style: AppTextStyles.nunito(
                  13,
                  weight: FontWeight.w800,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: AppColors.panel,
              valueColor: const AlwaysStoppedAnimation(AppColors.teal),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard();

  @override
  Widget build(BuildContext context) {
    final lessons = _week.where((d) => d.minutes > 0).length;
    final minutes =
        _week.fold<int>(0, (total, day) => total + day.minutes);
    final maxMinutes = _week
        .map((d) => d.minutes)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    const today = 4; // highlighted bar in the design (sexta-feira)

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Esta semana', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 14),
          SizedBox(
            height: 90,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 10,
              children: [
                for (var i = 0; i < _week.length; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: _week[i].minutes == 0
                              ? 6
                              : 60 * _week[i].minutes / maxMinutes + 6,
                          decoration: BoxDecoration(
                            color: _week[i].minutes == 0
                                ? AppColors.panel
                                : i == today
                                    ? AppColors.orange
                                    : AppColors.teal,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                              bottom: Radius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _week[i].label,
                          style: AppTextStyles.nunito(
                            11,
                            weight: FontWeight.w700,
                            color: _week[i].minutes == 0
                                ? AppColors.textDisabled
                                : AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$lessons lições completas · $minutes min de prática',
            style: AppTextStyles.nunito(13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.module});

  final LearningModule module;

  @override
  Widget build(BuildContext context) {
    final (chipColor, statusLabel, statusColor) = switch (module.status) {
      ModuleStatus.done => (
          AppColors.teal,
          'Completo',
          AppColors.teal,
        ),
      ModuleStatus.current => (
          AppColors.orange,
          '${(module.progress * 100).round()}%',
          AppColors.orangeDark,
        ),
      ModuleStatus.locked => (
          AppColors.borderMuted,
          'Bloqueado',
          AppColors.textDisabled,
        ),
    };
    final isCurrent = module.status == ModuleStatus.current;
    final titleColor = module.status == ModuleStatus.locked
        ? AppColors.textFaint
        : AppColors.textDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent ? AppColors.orange : AppColors.border,
          width: 2,
        ),
      ),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${module.number}',
              style: AppTextStyles.baloo(16, color: Colors.white),
            ),
          ),
          Expanded(
            child: Text(
              module.title,
              style: AppTextStyles.nunito(
                15,
                weight: FontWeight.w700,
                color: titleColor,
              ),
            ),
          ),
          Text(
            statusLabel,
            style: AppTextStyles.nunito(
              13,
              weight: FontWeight.w800,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}
