import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_card.dart';
import '../../../core/widgets/lele_icon_button.dart';
import '../../../core/widgets/lele_mascot.dart';
import '../../../core/widgets/motion.dart';
import '../../learning/application/journey_provider.dart';
import '../../learning/domain/learning_module.dart';
import '../../session/application/progress_provider.dart';

class ChildHomeScreen extends ConsumerWidget {
  const ChildHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final journey = ref.watch(journeyProvider);
    final currentModule = ref.watch(currentModuleProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: Row(
                spacing: AppSpacing.sm,
                children: [
                  LeleIconButton(
                    icon: Icons.menu_rounded,
                    onPressed: () => context.goNamed(AppRoutes.dashboard),
                    semanticLabel: 'Abrir a área dos pais',
                    size: 38,
                    iconSize: 20,
                    alignment: Alignment.centerLeft,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // The stat pills wrap to a second line rather than
                  // pushing each other off the edge of a small phone.
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _StatPill(
                          color: AppColors.orangeDark,
                          icon: const Icon(
                            Icons.bolt_rounded,
                            size: 16,
                            color: AppColors.orangeDark,
                          ),
                          value: '${progress.streak}',
                        ),
                        _StatPill(
                          color: AppColors.yellowDark,
                          icon: Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              color: AppColors.yellow,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.yellowDark,
                                width: 2.5,
                              ),
                            ),
                          ),
                          value: '${progress.coins}',
                        ),
                        _StatPill(
                          color: AppColors.purple,
                          icon: const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: AppColors.purple,
                          ),
                          value: '${progress.xp}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.sm,
                  AppSpacing.xxl,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TodayLessonCard(
                      theme: currentModule.lessonTheme,
                      onTap: () => context.goNamed(AppRoutes.lessonIntro),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text('Sua jornada', style: AppTextStyles.subheading),
                    const SizedBox(height: AppSpacing.sm),
                    for (final (i, module) in journey.indexed)
                      _JourneyRow(
                        module: module,
                        indented: i.isOdd,
                        onTap: module.status == ModuleStatus.current
                            ? () => context.goNamed(AppRoutes.lessonIntro)
                            : null,
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    _BooksCard(onTap: () => context.goNamed(AppRoutes.books)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.color,
    required this.icon,
    required this.value,
  });

  final Color color;
  final Widget icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return LeleCard(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      borderRadius: AppRadius.control,
      child: Row(
        // Without this the Row takes the Wrap's full width, so each pill
        // became a full-width bar on its own line instead of three chips
        // sitting together next to the menu button.
        mainAxisSize: MainAxisSize.min,
        spacing: 5,
        children: [
          icon,
          Text(value, style: AppTextStyles.statValue.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _TodayLessonCard extends StatelessWidget {
  const _TodayLessonCard({required this.theme, required this.onTap});

  /// Theme of the module the child is on, e.g. "Sons e rimas".
  final String theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PulsingWidget(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.orangeBright, AppColors.orange],
            ),
            borderRadius: BorderRadius.circular(AppRadius.panel),
            boxShadow: const [
              BoxShadow(color: AppColors.orangeDark, offset: Offset(0, 6)),
            ],
          ),
          child: Row(
            spacing: AppSpacing.lg,
            children: [
              const LeleMascot(size: 58),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lição de hoje',
                      style: AppTextStyles.subheading.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '$theme · 15 min',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.orangePale,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 32,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyRow extends StatelessWidget {
  const _JourneyRow({required this.module, required this.indented, this.onTap});

  final LearningModule module;
  final bool indented;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (
      bg,
      borderColor,
      textColor,
      subColor,
      statusLabel,
    ) = switch (module.status) {
      ModuleStatus.done => (
        AppColors.teal,
        AppColors.tealDark,
        AppColors.textDark,
        AppColors.textFaint,
        'Completo',
      ),
      ModuleStatus.current => (
        AppColors.orange,
        AppColors.orangeDark,
        AppColors.textDark,
        AppColors.orangeDark,
        'Você está aqui!',
      ),
      ModuleStatus.locked => (
        AppColors.panel,
        AppColors.borderDark,
        AppColors.textFaint,
        AppColors.textFaint,
        'Em breve',
      ),
    };

    return Padding(
      padding: EdgeInsets.only(top: 9, bottom: 9, left: indented ? 44 : 0),
      child: Row(
        spacing: AppSpacing.lg,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 66,
              height: 66,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 4),
                boxShadow: [
                  BoxShadow(color: borderColor, offset: const Offset(0, 5)),
                ],
              ),
              child: switch (module.status) {
                ModuleStatus.done => const Icon(
                  Icons.check_rounded,
                  size: 30,
                  color: Colors.white,
                ),
                ModuleStatus.current => const Icon(
                  Icons.star_rounded,
                  size: 30,
                  color: Colors.white,
                ),
                ModuleStatus.locked => const SizedBox.shrink(),
              },
            ),
          ),
          // Bounded, so a long module title wraps instead of running off
          // the side of a narrow phone.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.title,
                  style: AppTextStyles.statValue.copyWith(color: textColor),
                ),
                Text(
                  statusLabel,
                  style: AppTextStyles.nunito(
                    12,
                    weight: FontWeight.w700,
                    color: subColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BooksCard extends StatelessWidget {
  const _BooksCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LeleCard(
      onTap: onTap,
      semanticLabel: 'Meus livros',
      child: Row(
        spacing: AppSpacing.lg,
        children: [
          Container(
            width: 44,
            height: 52,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.purple, AppColors.purpleBright],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border(
                left: BorderSide(color: AppColors.purpleDark, width: 6),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Meus livros', style: AppTextStyles.sectionTitle),
                Text(
                  '2 desbloqueados · 1 novo!',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 28,
            color: AppColors.textFaint,
          ),
        ],
      ),
    );
  }
}
