import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../../../core/widgets/lele_mascot.dart';
import '../../learning/application/journey_provider.dart';
import '../../learning/domain/learning_module.dart';
import '../../auth/data/auth_repository.dart';
import '../../paywall/application/entitlement_provider.dart';
import '../../session/application/child_provider.dart';
import '../../session/application/parent_provider.dart';
import '../../session/application/progress_provider.dart';
import '../../session/domain/child_profile.dart';

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
    final child = ref.watch(childProvider);
    final progress = ref.watch(progressProvider);
    // Whoever actually registered, per the backend — not the sample name.
    final parentName = ref.watch(parentNameProvider);
    final journey = ref.watch(journeyProvider);
    final currentModule = ref.watch(currentModuleProvider);

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
                                parentName.isEmpty
                                    ? 'Olá!'
                                    : 'Olá, $parentName',
                                style: AppTextStyles.baloo(26),
                              ),
                            ],
                          ),
                        ),
                        if (ref.watch(isPremiumProvider))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.greenPale,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              'Premium ativo',
                              style: AppTextStyles.baloo(
                                13,
                                color: AppColors.greenDark,
                              ),
                            ),
                          )
                        else
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
                              // Shortened to leave room for sign-out; the
                              // paywall spells the offer out in full.
                              child: Text(
                                'Teste grátis',
                                style: AppTextStyles.baloo(
                                  13,
                                  color: AppColors.purple,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        _SignOutButton(
                          onSignOut: () =>
                              ref.read(authRepositoryProvider).signOut(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _ChildCard(
                      child: child,
                      streak: progress.streak,
                      moduleTitle: currentModule.title,
                      progress: currentModule.progress,
                    ),
                    const SizedBox(height: 16),
                    const _WeekCard(),
                    const SizedBox(height: 16),
                    Text(
                      'Jornada de aprendizado',
                      style: AppTextStyles.sectionTitle,
                    ),
                    const SizedBox(height: 10),
                    for (final module in journey) ...[
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

/// Leaves the account. The router sends the parent back to sign-in as soon
/// as auth state clears, so nothing else has to happen here.
class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Sair da conta',
      child: GestureDetector(
        onTap: onSignOut,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.logout_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({
    required this.child,
    required this.streak,
    required this.moduleTitle,
    required this.progress,
  });

  final ChildProfile child;
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
              LeleMascot(
                size: 54,
                color: child.avatar.color,
                mouthColor: child.avatar.mouthColor,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${child.name} · ${child.age} anos',
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
                  const Icon(
                    Icons.bolt_rounded,
                    size: 18,
                    color: AppColors.orangeDark,
                  ),
                  Text(
                    '$streak',
                    style: AppTextStyles.baloo(15, color: AppColors.orangeDark),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Progresso do módulo',
                  style: AppTextStyles.nunito(
                    13,
                    weight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
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
    final minutes = _week.fold<int>(0, (total, day) => total + day.minutes);
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
      ModuleStatus.done => (AppColors.teal, 'Completo', AppColors.teal),
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
