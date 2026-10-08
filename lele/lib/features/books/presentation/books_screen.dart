import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/layout/adaptive_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_icon_button.dart';
import '../domain/book.dart';
import 'book_cover_style.dart';

class BooksScreen extends StatelessWidget {
  const BooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const showDemoBooks = !AppConfig.useFirebase;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                spacing: AppSpacing.md,
                children: [
                  LeleIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => context.goNamed(AppRoutes.childHome),
                    semanticLabel: 'Voltar',
                    alignment: Alignment.centerLeft,
                  ),
                  Flexible(
                    child: Text('Meus livros', style: AppTextStyles.heading),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                showDemoBooks
                    ? 'Complete lições para desbloquear novos livros!'
                    : 'Sua biblioteca vai guardar as histórias da sua jornada.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (showDemoBooks)
                GridView.count(
                  // Two covers on a phone, more once there is room — a
                  // two-column grid on a tablet leaves each cover absurdly
                  // large.
                  crossAxisCount: switch (context.windowClass) {
                    WindowClass.compact => 2,
                    WindowClass.medium => 3,
                    WindowClass.expanded => 4,
                  },
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.lg,
                  crossAxisSpacing: AppSpacing.lg,
                  // The title under each cover grows with the text scale, so
                  // the tile has to get taller with it or the column overflows.
                  childAspectRatio:
                      0.82 /
                      (1 +
                          (MediaQuery.textScalerOf(context).scale(1) - 1) *
                              0.6),
                  children: [
                    for (final book in bookLibrary) _BookTile(book: book),
                  ],
                )
              else
                const _EmptyLibrary(),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.auto_stories_rounded,
            size: 56,
            color: AppColors.teal,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Ainda não há livros disponíveis',
            textAlign: TextAlign.center,
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Quando novas histórias forem publicadas, elas aparecerão aqui.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final cover = coverOf(book);
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              topRight: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: cover.gradient,
                    ),
                    border: Border(
                      left: BorderSide(color: cover.spine, width: 10),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    book.initial,
                    style: AppTextStyles.baloo(
                      34,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                if (book.locked) _LockedOverlay(hint: book.unlockHint!),
                if (book.isNew)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        borderRadius: BorderRadius.circular(AppRadius.bar),
                      ),
                      child: Text(
                        'NOVO',
                        style: AppTextStyles.micro.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyles.statValue.copyWith(
            color: book.locked ? AppColors.textFaint : AppColors.textDark,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _LockedOverlay extends StatelessWidget {
  const _LockedOverlay({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.textDark.withValues(alpha: 0.55),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: AppSpacing.sm,
        children: [
          const Icon(Icons.lock_rounded, size: 28, color: AppColors.yellow),
          Text(
            hint,
            style: AppTextStyles.nunito(
              11,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
