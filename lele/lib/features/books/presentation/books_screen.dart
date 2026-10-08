import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/layout/adaptive_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_icon_button.dart';
import '../../paywall/application/entitlement_provider.dart';
import '../application/book_providers.dart';
import '../domain/book.dart';
import 'book_cover_style.dart';
import 'book_illustration.dart';

class BooksScreen extends ConsumerStatefulWidget {
  const BooksScreen({super.key});
  @override
  ConsumerState<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends ConsumerState<BooksScreen> {
  BookAccess? _filter;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(bookCatalogProvider);
    final premium = ref.watch(premiumBooksActiveProvider);
    final bookmarks = ref.watch(bookBookmarksProvider);
    final saved = bookmarks.isLoading || bookmarks.hasError
        ? const <String, BookBookmark>{}
        : bookmarks.value ?? const {};
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                        child: Text(
                          'Meus livros',
                          style: AppTextStyles.heading,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.tealPale,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_stories_rounded,
                          size: 42,
                          color: AppColors.tealDark,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vamos ler juntos?',
                                style: AppTextStyles.sectionTitle,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Escolha uma história. Você pode ler ou ouvir cada página!',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: _filter == null,
                        onSelected: (_) => setState(() => _filter = null),
                      ),
                      ChoiceChip(
                        label: const Text('Grátis'),
                        selected: _filter == BookAccess.free,
                        onSelected: (_) =>
                            setState(() => _filter = BookAccess.free),
                      ),
                      ChoiceChip(
                        label: const Text('Premium'),
                        selected: _filter == BookAccess.premium,
                        onSelected: (_) =>
                            setState(() => _filter = BookAccess.premium),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (bookmarks.hasError)
                    TextButton.icon(
                      onPressed: () => ref.invalidate(bookBookmarksProvider),
                      icon: const Icon(Icons.sync_rounded),
                      label: const Text(
                        'Não carregamos suas páginas salvas. Tentar de novo',
                      ),
                    ),
                  catalog.when(
                    skipLoadingOnReload: false,
                    skipLoadingOnRefresh: false,
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (_, _) => _LibraryMessage(
                      icon: Icons.cloud_off_rounded,
                      title: 'Não conseguimos abrir a biblioteca',
                      message: 'Confira sua conexão e tente novamente.',
                      onRetry: () => ref.invalidate(bookCatalogProvider),
                    ),
                    data: (books) {
                      final visible = books
                          .where(
                            (book) => _filter == null || book.access == _filter,
                          )
                          .toList();
                      if (visible.isEmpty) {
                        return _LibraryMessage(
                          icon: Icons.auto_stories_rounded,
                          title: books.isEmpty
                              ? 'Ainda não há livros disponíveis'
                              : 'Nenhuma história nesta seleção',
                          message: books.isEmpty
                              ? 'Quando novas histórias forem publicadas, elas aparecerão aqui.'
                              : 'Toque em Todos para conhecer as outras histórias.',
                        );
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: visible.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: switch (context.windowClass) {
                            WindowClass.compact => 2,
                            WindowClass.medium => 3,
                            WindowClass.expanded => 4,
                          },
                          mainAxisExtent:
                              280 +
                              (MediaQuery.textScalerOf(context).scale(1) - 1) *
                                  75,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                        ),
                        itemBuilder: (context, index) {
                          final book = visible[index];
                          final locked =
                              book.access == BookAccess.premium &&
                              (premium.isLoading ||
                                  premium.hasError ||
                                  premium.value != true);
                          return _BookTile(
                            book: book,
                            locked: locked,
                            bookmark: saved[book.id],
                            onTap:
                                book.access == BookAccess.premium &&
                                    premium.isLoading
                                ? null
                                : () {
                                    if (locked) {
                                      context.pushNamed(AppRoutes.paywall);
                                    } else if (ref.read(
                                          bookReadingScopeProvider,
                                        ) ==
                                        null) {
                                      context.pushNamed(AppRoutes.profileSetup);
                                    } else {
                                      context.pushNamed(
                                        AppRoutes.bookReader,
                                        pathParameters: {'bookId': book.id},
                                      );
                                    }
                                  },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({
    required this.book,
    required this.locked,
    required this.bookmark,
    required this.onTap,
  });
  final Book book;
  final bool locked;
  final BookBookmark? bookmark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final resume = bookmark?.contentVersion == book.contentVersion;
    final page = resume
        ? (bookmark!.pageIndex + 1).clamp(1, book.pageCount)
        : null;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: locked ? '${book.title}, Premium' : 'Ler ${book.title}',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          key: ValueKey('book-${book.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      BookIllustration(
                        scene: book.coverKey,
                        cover: coverOf(book),
                        isCover: true,
                      ),
                      if (locked)
                        Positioned(
                          right: 9,
                          top: 9,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              size: 19,
                              color: AppColors.purpleDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(48),
                  child: Center(
                    child: Text(
                      book.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.statValue.copyWith(
                        fontSize: 17,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
                Text(
                  book.access == BookAccess.free ? 'GRÁTIS' : 'PREMIUM',
                  style: AppTextStyles.micro.copyWith(
                    color: book.access == BookAccess.free
                        ? AppColors.tealDark
                        : AppColors.purpleDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  page == null
                      ? '${book.pageCount} páginas'
                      : 'Continuar • $page de ${book.pageCount}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryMessage extends StatelessWidget {
  const _LibraryMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Column(
      children: [
        Icon(icon, size: 56, color: AppColors.teal),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.sectionTitle,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall,
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
      ],
    ),
  );
}
