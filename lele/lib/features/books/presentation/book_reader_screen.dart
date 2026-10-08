import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/layout/adaptive_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/lele_button.dart';
import '../../../core/widgets/lele_icon_button.dart';
import '../application/book_reader_controller.dart';
import 'book_cover_style.dart';
import 'book_illustration.dart';

class BookReaderScreen extends ConsumerStatefulWidget {
  const BookReaderScreen({super.key, required this.bookId});
  final String bookId;
  @override
  ConsumerState<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends ConsumerState<BookReaderScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(bookReaderControllerProvider(widget.bookId));
    if (state == AppLifecycleState.resumed) {
      unawaited(controller.load());
    } else {
      unawaited(controller.stopSpeaking());
    }
  }

  void _backToLibrary() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoutes.books);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(bookReaderControllerProvider(widget.bookId));
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        final content = state.content;
        return Scaffold(
          body: SafeArea(
            child: AdaptiveWidth(
              maxWidth: 700,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Row(
                      children: [
                        LeleIconButton(
                          icon: Icons.arrow_back_rounded,
                          semanticLabel: 'Voltar aos livros',
                          alignment: Alignment.centerLeft,
                          onPressed: _backToLibrary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            content?.book.title ?? 'Hora da história',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.sectionTitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: state.loading
                        ? const Center(child: CircularProgressIndicator())
                        : content == null
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(
                                  state.premiumRequired
                                      ? Icons.lock_rounded
                                      : Icons.menu_book_rounded,
                                  size: 72,
                                  color: AppColors.purple,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  state.error ??
                                      'Esta história não está disponível.',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.body,
                                ),
                                const SizedBox(height: 24),
                                LeleButton(
                                  label: state.premiumRequired
                                      ? 'Ver planos'
                                      : 'Tentar de novo',
                                  onPressed: state.premiumRequired
                                      ? () =>
                                            context.pushNamed(AppRoutes.paywall)
                                      : () => unawaited(controller.load()),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _backToLibrary,
                                  child: const Text('Voltar aos livros'),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            key: ValueKey('book-scroll-${state.pageIndex}'),
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: Column(
                                key: ValueKey(
                                  '${content.book.contentVersion}-${state.pageIndex}',
                                ),
                                children: [
                                  AspectRatio(
                                    aspectRatio: 1.6,
                                    child: BookIllustration(
                                      scene: state.page!.illustration,
                                      cover: coverOf(content.book),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    state.page!.text,
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.nunito(
                                      25,
                                      weight: FontWeight.w800,
                                    ).copyWith(height: 1.5),
                                  ),
                                  const SizedBox(height: 20),
                                  OutlinedButton.icon(
                                    onPressed: state.busy
                                        ? null
                                        : () => unawaited(
                                            controller.toggleNarration(),
                                          ),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(160, 54),
                                    ),
                                    icon: Icon(
                                      state.speaking
                                          ? Icons.stop_rounded
                                          : Icons.volume_up_rounded,
                                    ),
                                    label: Text(
                                      state.speaking
                                          ? 'Parar leitura'
                                          : 'Ouvir página',
                                    ),
                                  ),
                                  if (state.isLastPage) ...[
                                    const SizedBox(height: 20),
                                    const Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 38,
                                      color: AppColors.yellowDark,
                                    ),
                                    Text(
                                      'Fim da história!',
                                      style: AppTextStyles.heading,
                                    ),
                                    TextButton.icon(
                                      onPressed: state.busy
                                          ? null
                                          : () =>
                                                unawaited(controller.restart()),
                                      icon: const Icon(Icons.replay_rounded),
                                      label: const Text('Ler de novo'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                  ),
                  if (content != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Column(
                        children: [
                          if (state.saveError != null)
                            TextButton.icon(
                              onPressed: state.busy
                                  ? null
                                  : () => unawaited(controller.retrySave()),
                              icon: const Icon(
                                Icons.sync_problem_rounded,
                                color: AppColors.redDark,
                              ),
                              label: Text(
                                state.saveError!,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          Semantics(
                            label:
                                'Página ${state.pageIndex + 1} de ${content.pages.length}',
                            child: LinearProgressIndicator(
                              value:
                                  (state.pageIndex + 1) / content.pages.length,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(20),
                              color: AppColors.teal,
                              backgroundColor: AppColors.creamDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${state.pageIndex + 1} de ${content.pages.length}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              IconButton.filledTonal(
                                tooltip: 'Página anterior',
                                onPressed: state.busy || state.pageIndex == 0
                                    ? null
                                    : () =>
                                          unawaited(controller.previousPage()),
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(54, 58),
                                ),
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: LeleButton(
                                  key: const ValueKey('book-next'),
                                  label: state.isLastPage
                                      ? 'Voltar aos livros'
                                      : 'Próxima página',
                                  fontSize: 18,
                                  enabled: !state.busy,
                                  onPressed: state.isLastPage
                                      ? _backToLibrary
                                      : () => unawaited(controller.nextPage()),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
