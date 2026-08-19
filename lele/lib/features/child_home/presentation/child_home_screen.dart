import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_mascot.dart';
import '../../learning/domain/learning_module.dart';
import '../../session/application/session_controller.dart';

class ChildHomeScreen extends ConsumerWidget {
  const ChildHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Row(
                spacing: 8,
                children: [
                  GestureDetector(
                    onTap: () => context.goNamed(AppRoutes.dashboard),
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.panel,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.menu_rounded,
                          size: 20, color: AppColors.textMuted),
                    ),
                  ),
                  const Spacer(),
                  _StatPill(
                    color: AppColors.orangeDark,
                    icon: const Icon(Icons.bolt_rounded,
                        size: 16, color: AppColors.orangeDark),
                    value: '${session.streak}',
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
                    value: '${session.coins}',
                  ),
                  _StatPill(
                    color: AppColors.purple,
                    icon: const Icon(Icons.star_rounded,
                        size: 16, color: AppColors.purple),
                    value: '${session.xp}',
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TodayLessonCard(
                      onTap: () => context.goNamed(AppRoutes.lessonIntro),
                    ),
                    const SizedBox(height: 22),
                    Text('Sua jornada', style: AppTextStyles.baloo(17)),
                    const SizedBox(height: 6),
                    for (final (i, module) in learningJourney.indexed)
                      _JourneyRow(
                        module: module,
                        indented: i.isOdd,
                        onTap: module.status == ModuleStatus.current
                            ? () => context.goNamed(AppRoutes.lessonIntro)
                            : null,
                      ),
                    const SizedBox(height: 14),
                    _BooksCard(
                      onTap: () => context.goNamed(AppRoutes.books),
                    ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Row(
        spacing: 5,
        children: [
          icon,
          Text(value, style: AppTextStyles.baloo(14, color: color)),
        ],
      ),
    );
  }
}

class _TodayLessonCard extends StatelessWidget {
  const _TodayLessonCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PulsingWidget(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.orangeBright, AppColors.orange],
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(color: AppColors.orangeDark, offset: Offset(0, 6)),
            ],
          ),
          child: Row(
            spacing: 14,
            children: [
              const LeleMascot(size: 58),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lição de hoje',
                      style: AppTextStyles.baloo(19, color: Colors.white),
                    ),
                    Text(
                      'Sons e rimas · 15 min',
                      style: AppTextStyles.nunito(
                        13,
                        weight: FontWeight.w700,
                        color: AppColors.orangePale,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 32, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyRow extends StatelessWidget {
  const _JourneyRow({
    required this.module,
    required this.indented,
    this.onTap,
  });

  final LearningModule module;
  final bool indented;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, borderColor, textColor, subColor, statusLabel) =
        switch (module.status) {
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
      padding: EdgeInsets.only(
        top: 9,
        bottom: 9,
        left: indented ? 44 : 0,
      ),
      child: Row(
        spacing: 14,
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
                ModuleStatus.done => const Icon(Icons.check_rounded,
                    size: 30, color: Colors.white),
                ModuleStatus.current => const Icon(Icons.star_rounded,
                    size: 30, color: Colors.white),
                ModuleStatus.locked => const SizedBox.shrink(),
              },
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                module.title,
                style: AppTextStyles.baloo(15, color: textColor),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border, width: 2),
        ),
        child: Row(
          spacing: 14,
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
                  Text('Meus livros', style: AppTextStyles.baloo(16)),
                  Text(
                    '2 desbloqueados · 1 novo!',
                    style: AppTextStyles.nunito(
                      13,
                      weight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 28, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }
}
