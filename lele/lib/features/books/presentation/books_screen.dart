import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../domain/book.dart';

class BooksScreen extends StatelessWidget {
  const BooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                spacing: 12,
                children: [
                  GestureDetector(
                    onTap: () => context.goNamed(AppRoutes.childHome),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.panel,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          size: 22, color: AppColors.textMuted),
                    ),
                  ),
                  Text('Meus livros', style: AppTextStyles.baloo(24)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Complete lições para desbloquear novos livros!',
                style: AppTextStyles.nunito(14, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.82,
                children: [
                  for (final book in bookLibrary) _BookTile(book: book),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
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
                      colors: book.coverColors,
                    ),
                    border: Border(
                      left: BorderSide(color: book.spineColor, width: 10),
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
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'NOVO',
                        style: AppTextStyles.baloo(10, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          book.title,
          textAlign: TextAlign.center,
          style: AppTextStyles.baloo(
            14,
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
    return Container(
      color: AppColors.textDark.withValues(alpha: 0.55),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 6,
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
