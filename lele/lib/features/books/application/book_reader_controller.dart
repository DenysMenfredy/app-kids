import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/tts_service.dart';
import '../../paywall/application/entitlement_provider.dart';
import '../data/book_repository.dart';
import '../domain/book.dart';
import 'book_providers.dart';

class BookReaderState {
  const BookReaderState({
    this.loading = false,
    this.busy = false,
    this.content,
    this.pageIndex = 0,
    this.error,
    this.saveError,
    this.premiumRequired = false,
    this.speaking = false,
  });

  final bool loading;
  final bool busy;
  final BookContent? content;
  final int pageIndex;
  final String? error;
  final String? saveError;
  final bool premiumRequired;
  final bool speaking;
  BookPage? get page => content?.pages[pageIndex];
  bool get isLastPage =>
      content != null && pageIndex == content!.pages.length - 1;
}

/// One reader run is bound to its original parent/child and content version.
class BookReaderController extends ChangeNotifier {
  BookReaderController({
    required BookRepository repository,
    required TtsService narrator,
    required this.bookId,
    required this.scope,
  }) : _repository = repository,
       _narrator = narrator {
    unawaited(load());
  }

  final BookRepository _repository;
  final TtsService _narrator;
  final String bookId;
  final ReadingScope? scope;
  BookReaderState _state = const BookReaderState(loading: true);
  BookReaderState get state => _state;
  bool _disposed = false;
  int _loadGeneration = 0;
  int _speechGeneration = 0;

  void _set(BookReaderState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  Future<void> load() async {
    final generation = ++_loadGeneration;
    _set(const BookReaderState(loading: true));
    await stopSpeaking();
    if (_disposed || generation != _loadGeneration) return;
    try {
      if (scope == null) {
        throw const BookFailure('Selecione o perfil da criança para ler.');
      }
      final content = await _repository.loadContent(bookId);
      final bookmark = await _repository.loadBookmark(scope!, bookId);
      if (_disposed || generation != _loadGeneration) return;
      final index = bookmark?.contentVersion == content.book.contentVersion
          ? bookmark!.pageIndex.clamp(0, content.pages.length - 1)
          : 0;
      _set(BookReaderState(content: content, pageIndex: index));
    } catch (error) {
      if (generation == _loadGeneration) _fail(error);
    }
  }

  Future<void> nextPage() => _moveTo(_state.pageIndex + 1);
  Future<void> previousPage() => _moveTo(_state.pageIndex - 1);
  Future<void> restart() => _moveTo(0);

  Future<void> _moveTo(int pageIndex) async {
    final old = _state;
    if (_disposed ||
        old.busy ||
        old.loading ||
        old.content == null ||
        pageIndex < 0 ||
        pageIndex >= old.content!.pages.length) {
      return;
    }
    final generation = ++_loadGeneration;
    _set(
      BookReaderState(
        content: old.content,
        pageIndex: old.pageIndex,
        busy: true,
      ),
    );
    await stopSpeaking();
    try {
      // Re-read online so revoked/unpublished content cannot authorize a turn.
      final content = await _repository.loadContent(bookId);
      if (_disposed || generation != _loadGeneration) return;
      final index =
          content.book.contentVersion == old.content!.book.contentVersion
          ? pageIndex.clamp(0, content.pages.length - 1)
          : 0;
      _set(BookReaderState(content: content, pageIndex: index, busy: true));
      await _save(content, index, generation);
    } catch (error) {
      if (generation == _loadGeneration) _fail(error);
    }
  }

  Future<void> retrySave() async {
    if (_state.busy || _state.content == null) return;
    final generation = ++_loadGeneration;
    final content = _state.content!;
    final index = _state.pageIndex;
    _set(BookReaderState(content: content, pageIndex: index, busy: true));
    await _save(content, index, generation);
  }

  Future<void> _save(BookContent content, int index, int generation) async {
    if (scope == null || _disposed) return;
    try {
      await _repository.saveBookmark(scope!, content.book, index);
      if (_disposed || generation != _loadGeneration) return;
      _set(BookReaderState(content: content, pageIndex: index));
    } catch (_) {
      if (_disposed || generation != _loadGeneration) return;
      _set(
        BookReaderState(
          content: content,
          pageIndex: index,
          saveError: 'Não salvamos sua página. Toque para tentar novamente.',
        ),
      );
    }
  }

  Future<void> toggleNarration() async {
    if (_state.speaking) return stopSpeaking();
    if (_state.page == null || _state.busy) return;
    final generation = ++_speechGeneration;
    final current = _state;
    _set(
      BookReaderState(
        content: current.content,
        pageIndex: current.pageIndex,
        saveError: current.saveError,
        speaking: true,
      ),
    );
    await _narrator.speak(current.page!.text);
    if (!_disposed && generation == _speechGeneration) {
      _set(
        BookReaderState(
          content: _state.content,
          pageIndex: _state.pageIndex,
          saveError: _state.saveError,
        ),
      );
    }
  }

  Future<void> stopSpeaking() async {
    _speechGeneration++;
    await _narrator.stop();
    if (_state.speaking) {
      _set(
        BookReaderState(
          content: _state.content,
          pageIndex: _state.pageIndex,
          saveError: _state.saveError,
          busy: _state.busy,
        ),
      );
    }
  }

  void _fail(Object error) {
    final failure = error is BookFailure
        ? error
        : const BookFailure(
            'Não foi possível carregar a história. Verifique a conexão e tente novamente.',
          );
    _set(
      BookReaderState(
        error: failure.message,
        premiumRequired: failure.premiumRequired,
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    _speechGeneration++;
    unawaited(_narrator.stop());
    super.dispose();
  }
}

final bookReaderControllerProvider = Provider.autoDispose
    .family<BookReaderController, String>((ref, bookId) {
      final scope = ref.watch(bookReadingScopeProvider);
      // Clear the loaded page when the entitlement expires or is revoked.
      ref.watch(premiumBooksActiveProvider);
      final controller = BookReaderController(
        repository: ref.watch(bookRepositoryProvider),
        narrator: ref.read(ttsServiceProvider),
        bookId: bookId,
        scope: scope,
      );
      ref.onDispose(controller.dispose);
      return controller;
    });
