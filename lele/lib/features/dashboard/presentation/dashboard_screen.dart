import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../../../core/widgets/lele_card.dart';
import '../../../core/widgets/lele_icon_button.dart';
import '../../../core/widgets/lele_mascot.dart';
import '../../../core/widgets/motion.dart';
import '../../auth/application/auth_controller.dart';
import '../../learning/application/journey_provider.dart';
import '../../learning/domain/learning_module.dart';
import '../../paywall/application/entitlement_provider.dart';
import '../../session/application/child_provider.dart';
import '../../session/application/parent_provider.dart';
import '../../session/application/progress_provider.dart';
import '../../session/application/session_controller.dart';
import '../../session/domain/child_profile.dart';
import '../../session/presentation/child_avatar_style.dart';

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
    final parentName = ref.watch(parentFirstNameProvider);
    final journey = ref.watch(journeyProvider);
    final currentModule = ref.watch(currentModuleProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                  AppSpacing.sm,
                ),
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
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textFaint,
                                ),
                              ),
                              // One line, always. The header sits above a
                              // fixed stack of cards, and a greeting that
                              // wraps pushes all of them down — which is what
                              // a full name used to do here before the
                              // greeting was cut to the first name. A first
                              // name long enough to still not fit is
                              // ellipsised rather than allowed to wrap.
                              Text(
                                parentName.isEmpty
                                    ? 'Olá!'
                                    : 'Olá, $parentName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.title,
                              ),
                            ],
                          ),
                        ),
                        // Deliberately not Flexible. Flexible and the Expanded
                        // above are both flex children, so the row splits the
                        // free space evenly between them — and the chip only
                        // draws as wide as its text, leaving the rest of its
                        // half as dead space at the end of the row. That slack
                        // sat to the right of the sign-out button and pushed it
                        // off the margin, by 81px on a large phone and 198px on
                        // a tablet. A plain cap keeps the "give way rather than
                        // overflow" intent — the label is ellipsised — without
                        // claiming space it will not use. The cap is needed:
                        // a non-flex child of a Row is measured unbounded.
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: _StatusChip(
                            premium: ref.watch(isPremiumProvider),
                            onTap: () => context.goNamed(AppRoutes.paywall),
                          ),
                        ),
                        // No gap of its own: the sign-out button's touch
                        // target already reserves 10px inside its left edge,
                        // which is the separation the design asks for. Adding
                        // AppSpacing.sm on top read as a double gap.
                        _SignOutButton(
                          onSignOut: () =>
                              ref.read(authControllerProvider).signOut(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ChildCard(
                      child: child,
                      streak: progress.streak,
                      moduleTitle: currentModule.title,
                      progress: currentModule.progress,
                    ),
                    if (AppConfig.useFirebase) ...[
                      const SizedBox(height: AppSpacing.xs),
                      const _ChildProfileSwitcher(),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    const _WeekCard(),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Jornada de aprendizado',
                      style: AppTextStyles.sectionTitle,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final module in journey) ...[
                      _ModuleRow(module: module),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.sm,
                AppSpacing.xxl,
                AppSpacing.xl,
              ),
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

class _ChildProfileSwitcher extends ConsumerWidget {
  const _ChildProfileSwitcher();

  Future<void> _openProfiles(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _ChildProfilesSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(remoteChildrenProvider).value ?? const [];
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () => _openProfiles(context),
        icon: const Icon(Icons.manage_accounts_outlined),
        label: Text(
          children.length > 1 ? 'Trocar perfil' : 'Perfis das crianças',
        ),
      ),
    );
  }
}

class _ChildProfilesSheet extends ConsumerWidget {
  const _ChildProfilesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenState = ref.watch(remoteChildrenProvider);
    final children = childrenState.value ?? const [];
    final activeId = ref.watch(activeChildIdProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Quem vai aprender?', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.md),
            if (childrenState.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (childrenState.hasError)
              Row(
                children: [
                  const Expanded(
                    child: Text('Não foi possível carregar os perfis.'),
                  ),
                  IconButton(
                    tooltip: 'Tentar novamente',
                    onPressed: () => ref.invalidate(remoteChildrenProvider),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              )
            else if (children.isEmpty)
              const Text('Nenhum perfil cadastrado ainda.'),
            for (final child in children)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  child.id == activeId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: AppColors.teal,
                ),
                title: Text(child.profile.name),
                subtitle: Text('${child.profile.age} anos'),
                trailing: IconButton(
                  tooltip: 'Editar perfil de ${child.profile.name}',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    ref.read(sessionProvider.notifier).selectChild(child);
                    Navigator.of(context).pop();
                    context.goNamed(
                      AppRoutes.profileSetup,
                      queryParameters: const {'edit': 'true'},
                    );
                  },
                ),
                onTap: () {
                  ref.read(sessionProvider.notifier).selectChild(child);
                  Navigator.of(context).pop();
                },
              ),
            const SizedBox(height: AppSpacing.sm),
            LeleButton(
              label: 'Adicionar criança',
              enabled: childrenState.hasValue,
              onPressed: () {
                Navigator.of(context).pop();
                context.goNamed(
                  AppRoutes.profileSetup,
                  queryParameters: const {'new': 'true'},
                );
              },
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
    return LeleIconButton(
      icon: Icons.logout_rounded,
      onPressed: onSignOut,
      semanticLabel: 'Sair da conta',
      size: 38,
      iconSize: 18,
      alignment: Alignment.centerRight,
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
    return LeleCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      borderRadius: AppRadius.panel,
      child: Column(
        children: [
          Row(
            spacing: AppSpacing.lg,
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
                      style: AppTextStyles.subheading,
                    ),
                    Text(
                      '$moduleTitle · Semana 2',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                spacing: AppSpacing.xs,
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    size: 18,
                    color: AppColors.orangeDark,
                  ),
                  Text(
                    '$streak',
                    style: AppTextStyles.statValue.copyWith(
                      color: AppColors.orangeDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Progresso do módulo',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              CountUp(
                value: percent,
                builder: (context, value) => Text(
                  '$value%',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.teal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Filled rather than drawn: a parent opening the dashboard after
          // a lesson sees the week's work arrive, and the bar and the
          // percentage above it move together.
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.bar),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 12,
                backgroundColor: AppColors.panel,
                valueColor: const AlwaysStoppedAnimation(AppColors.teal),
              ),
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

    return LeleCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      borderRadius: AppRadius.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Esta semana', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.lg),
          // The bars keep a fixed plot area; the row's height then follows
          // the day labels, which grow with the text scale. A fixed 90px box
          // overflowed by 2px the moment they did.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: AppSpacing.md,
            children: [
              for (var i = 0; i < _week.length; i++)
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 66,
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
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _week[i].label,
                        maxLines: 1,
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
          const SizedBox(height: AppSpacing.md),
          Text(
            '$lessons lições completas · $minutes min de prática',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
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
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(
          color: isCurrent ? AppColors.orange : AppColors.border,
          width: 2,
        ),
      ),
      child: Row(
        spacing: AppSpacing.md,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Text(
              '${module.number}',
              style: AppTextStyles.sectionTitle.copyWith(color: Colors.white),
            ),
          ),
          Expanded(
            child: Text(
              module.title,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
          ),
          Text(
            statusLabel,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w800,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// The premium-status pill in the dashboard header.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.premium, required this.onTap});

  final bool premium;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: premium ? AppColors.greenPale : AppColors.purplePale,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      // Do not promise a trial until its real billing flow is implemented.
      child: Text(
        premium ? 'Premium ativo' : 'Ver Premium',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.micro.copyWith(
          color: premium ? AppColors.greenDark : AppColors.purple,
        ),
      ),
    );
    return premium ? chip : GestureDetector(onTap: onTap, child: chip);
  }
}
