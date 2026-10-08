import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lele/app/router/app_router.dart';
import 'package:lele/core/services/tts_service.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/core/theme/app_theme.dart';
import 'package:lele/features/books/application/book_providers.dart';
import 'package:lele/features/books/application/book_reader_controller.dart';
import 'package:lele/features/books/data/book_repository.dart';
import 'package:lele/features/books/domain/book.dart';
import 'package:lele/features/books/presentation/book_reader_screen.dart';
import 'package:lele/features/books/presentation/books_screen.dart';
import 'package:lele/features/paywall/application/entitlement_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_fonts.dart';

class _Narrator extends TtsService {
  final spoken = <String>[];
  int stops = 0;
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {
    stops++;
  }
}

class _ScriptedRepository implements BookRepository {
  _ScriptedRepository(this.local);
  final BookRepository local;
  BookFailure? denied;
  Completer<void>? pendingSave;
  bool failSave = false;
  final savedScopes = <ReadingScope>[];
  @override
  Stream<List<Book>> watchCatalog() => local.watchCatalog();
  @override
  Future<BookContent> loadContent(String id) async {
    if (denied case final failure?) throw failure;
    return local.loadContent(id);
  }

  @override
  Future<BookBookmark?> loadBookmark(ReadingScope scope, String id) =>
      local.loadBookmark(scope, id);
  @override
  Stream<Map<String, BookBookmark>> watchBookmarks(ReadingScope scope) =>
      local.watchBookmarks(scope);
  @override
  Future<void> saveBookmark(ReadingScope scope, Book book, int index) async {
    savedScopes.add(scope);
    if (failSave) throw StateError('offline');
    if (pendingSave != null) await pendingSave!.future;
    await local.saveBookmark(scope, book, index);
  }
}

Future<void> _ready(BookReaderController controller) async {
  if (!controller.state.loading) return;
  final ready = Completer<void>();
  void listener() {
    if (!controller.state.loading && !ready.isCompleted) ready.complete();
  }

  controller.addListener(listener);
  await ready.future;
  controller.removeListener(listener);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  late SharedPreferences prefs;
  late LocalBookRepository local;
  const scopeA = (uid: 'parent-a', childId: 'child-a');
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    local = LocalBookRepository(prefs);
  });
  tearDown(() => local.dispose());

  test(
    'demo free stories exactly match the canonical published book seed',
    () async {
      final catalog =
          jsonDecode(
                File('../backend/seed/books/books.json').readAsStringSync(),
              )
              as List;
      final payloads =
          jsonDecode(
                File(
                  '../backend/seed/bookContents/bookContents.json',
                ).readAsStringSync(),
              )
              as List;
      final books = await local.watchCatalog().first;
      expect(books.length, catalog.length);
      for (final book in books) {
        final seed = catalog.cast<Map<String, dynamic>>().singleWhere(
          (entry) => entry['id'] == book.id,
        );
        expect(book, bookFromMap(book.id, seed));
        if (book.access == BookAccess.free) {
          final payload = payloads.cast<Map<String, dynamic>>().singleWhere(
            (entry) => entry['id'] == book.id,
          );
          expect(
            (await local.loadContent(book.id)).pages,
            bookContentFromMap(book, payload).pages,
          );
        } else {
          await expectLater(
            local.loadContent(book.id),
            throwsA(isA<BookFailure>()),
          );
        }
      }
    },
  );

  test('bookmarks resume independently for each child and parent', () async {
    final book = (await local.loadContent('sapo')).book;
    const scopeB = (uid: 'parent-a', childId: 'child-b');
    const scopeC = (uid: 'parent-b', childId: 'child-a');
    await local.saveBookmark(scopeA, book, 3);
    await local.saveBookmark(scopeB, book, 1);
    final controllers = [
      for (final scope in [scopeA, scopeB, scopeC])
        BookReaderController(
          repository: local,
          narrator: _Narrator(),
          bookId: 'sapo',
          scope: scope,
        ),
    ];
    for (final controller in controllers) {
      await _ready(controller);
    }
    expect(controllers.map((controller) => controller.state.pageIndex), [
      3,
      1,
      0,
    ]);
    for (final controller in controllers) {
      controller.dispose();
    }
  });

  test(
    'a revised story resets a stale bookmark instead of skipping new pages',
    () async {
      await prefs.setString(
        'books.parent-a.child-a.sapo',
        '{"pageIndex":4,"contentVersion":999}',
      );
      final reader = BookReaderController(
        repository: local,
        narrator: _Narrator(),
        bookId: 'sapo',
        scope: scopeA,
      );
      await _ready(reader);
      expect(reader.state.pageIndex, 0);
      reader.dispose();
    },
  );

  test(
    'revoked access blocks the next page and does not save a bookmark',
    () async {
      final repository = _ScriptedRepository(local);
      final reader = BookReaderController(
        repository: repository,
        narrator: _Narrator(),
        bookId: 'sapo',
        scope: scopeA,
      );
      await _ready(reader);
      repository.denied = const BookFailure(
        'Acesso encerrado',
        premiumRequired: true,
      );
      await reader.nextPage();
      expect(reader.state.content, isNull);
      expect(reader.state.premiumRequired, isTrue);
      expect(repository.savedScopes, isEmpty);
      reader.dispose();
    },
  );

  test(
    'late bookmark saves cannot restore content after access was revoked on resume',
    () async {
      final repository = _ScriptedRepository(local)
        ..pendingSave = Completer<void>();
      final reader = BookReaderController(
        repository: repository,
        narrator: _Narrator(),
        bookId: 'sapo',
        scope: scopeA,
      );
      await _ready(reader);
      final move = reader.nextPage();
      while (repository.savedScopes.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      repository.denied = const BookFailure('Livro indisponível');
      await reader.load();
      repository.pendingSave!.complete();
      await move;
      expect(reader.state.content, isNull);
      expect(reader.state.error, 'Livro indisponível');
      reader.dispose();
    },
  );

  test('failed bookmark saves remain visible and can be retried', () async {
    final repository = _ScriptedRepository(local)..failSave = true;
    final reader = BookReaderController(
      repository: repository,
      narrator: _Narrator(),
      bookId: 'sapo',
      scope: scopeA,
    );
    await _ready(reader);
    await reader.nextPage();
    expect(reader.state.pageIndex, 1);
    expect(reader.state.saveError, isNotNull);
    repository.failSave = false;
    await reader.retrySave();
    expect(reader.state.saveError, isNull);
    expect((await local.loadBookmark(scopeA, 'sapo'))!.pageIndex, 1);
    reader.dispose();
  });

  Future<GoRouter> pumpLibrary(
    WidgetTester tester, {
    String location = '/books',
  }) async {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/books',
          name: AppRoutes.books,
          builder: (_, _) => const BooksScreen(),
        ),
        GoRoute(
          path: '/books/:bookId',
          name: AppRoutes.bookReader,
          builder: (_, state) =>
              BookReaderScreen(bookId: state.pathParameters['bookId']!),
        ),
        GoRoute(
          path: '/paywall',
          name: AppRoutes.paywall,
          builder: (_, _) => const Scaffold(body: Text('Planos da família')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          bookRepositoryProvider.overrideWithValue(local),
          bookReadingScopeProvider.overrideWith((ref) => scopeA),
          premiumBooksActiveProvider.overrideWith(
            (ref) => const AsyncData(false),
          ),
          ttsServiceProvider.overrideWithValue(_Narrator()),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'shelf opens a free story, advances, finishes and resumes its saved page',
    (tester) async {
      await pumpLibrary(tester);
      expect(find.text('O Sapo e a Lua'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('book-sapo')));
      await tester.pumpAndSettle();
      expect(find.text('1 de 5'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const ValueKey('book-next')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Fim da história!'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('book-next')));
      await tester.pumpAndSettle();
      expect(find.text('Continuar • 5 de 5'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('book-sapo')));
      await tester.pumpAndSettle();
      expect(find.text('5 de 5'), findsOneWidget);
      await tester.ensureVisible(find.text('Ler de novo'));
      await tester.tap(find.text('Ler de novo'));
      await tester.pumpAndSettle();
      expect(find.text('1 de 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('locked covers and direct reader links both require Premium', (
    tester,
  ) async {
    final router = await pumpLibrary(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('book-trem')));
    await tester.tap(find.byKey(const ValueKey('book-trem')));
    await tester.pumpAndSettle();
    expect(find.text('Planos da família'), findsOneWidget);
    router.go('/books/trem');
    await tester.pumpAndSettle();
    expect(find.text('Ver planos'), findsOneWidget);
    expect(find.text('Esta história faz parte do Premium.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
