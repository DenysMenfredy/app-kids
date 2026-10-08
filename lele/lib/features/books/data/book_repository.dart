import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/storage/local_storage.dart';
import '../domain/book.dart';
import 'demo_books.dart';

abstract interface class BookRepository {
  Stream<List<Book>> watchCatalog();
  Future<BookContent> loadContent(String bookId);
  Stream<Map<String, BookBookmark>> watchBookmarks(ReadingScope scope);
  Future<BookBookmark?> loadBookmark(ReadingScope scope, String bookId);
  Future<void> saveBookmark(ReadingScope scope, Book book, int pageIndex);
}

class LocalBookRepository implements BookRepository {
  LocalBookRepository(this._prefs);
  final SharedPreferences _prefs;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<List<Book>> watchCatalog() => Stream.value(demoBooks);

  @override
  Future<BookContent> loadContent(String bookId) async {
    final books = demoBooks.where((book) => book.id == bookId);
    if (books.isEmpty) {
      throw const BookFailure('Esta história não está disponível.');
    }
    final pages = demoBookPages[bookId];
    if (pages == null) {
      throw const BookFailure(
        'Esta história faz parte do Premium.',
        premiumRequired: true,
      );
    }
    return BookContent(book: books.first, pages: pages);
  }

  String _key(ReadingScope scope, String bookId) =>
      'books.${scope.uid}.${scope.childId}.$bookId';

  @override
  Future<BookBookmark?> loadBookmark(ReadingScope scope, String bookId) async {
    final raw = _prefs.getString(_key(scope, bookId));
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? bookmarkFromMap(value) : null;
    } on FormatException {
      return null;
    }
  }

  Future<Map<String, BookBookmark>> _bookmarks(ReadingScope scope) async => {
    for (final book in demoBooks) book.id: ?await loadBookmark(scope, book.id),
  };

  @override
  Stream<Map<String, BookBookmark>> watchBookmarks(ReadingScope scope) async* {
    yield await _bookmarks(scope);
    yield* _changes.stream.asyncMap((_) => _bookmarks(scope));
  }

  @override
  Future<void> saveBookmark(
    ReadingScope scope,
    Book book,
    int pageIndex,
  ) async {
    await _prefs.setString(
      _key(scope, book.id),
      jsonEncode({
        'pageIndex': pageIndex,
        'contentVersion': book.contentVersion,
      }),
    );
    _changes.add(null);
  }

  void dispose() => _changes.close();
}

class FirestoreBookRepository implements BookRepository {
  FirestoreBookRepository(this._firestore, this._functions);
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Stream<List<Book>> watchCatalog() => _firestore
      .collection('books')
      .where('published', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
        final books =
            [for (final doc in snapshot.docs) ?bookFromMap(doc.id, doc.data())]
              ..sort((a, b) {
                final byOrder = a.order.compareTo(b.order);
                return byOrder == 0 ? a.id.compareTo(b.id) : byOrder;
              });
        return List.unmodifiable(books);
      });

  @override
  Future<BookContent> loadContent(String bookId) async {
    Book? book;
    try {
      final metadata = await _firestore
          .doc('books/$bookId')
          .get(const GetOptions(source: Source.server));
      book = bookFromMap(bookId, metadata.data() ?? {});
      if (book == null) {
        throw const BookFailure('Esta história não está disponível.');
      }
      final payload = await _firestore
          .doc('bookContents/$bookId')
          .get(const GetOptions(source: Source.server));
      return bookContentFromMap(book, payload.data() ?? {});
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' &&
          book?.access == BookAccess.premium) {
        throw const BookFailure(
          'Esta história precisa de Premium ativo.',
          premiumRequired: true,
        );
      }
      throw const BookFailure(
        'Não foi possível abrir a história. Verifique a conexão e tente novamente.',
      );
    }
  }

  String _bookmarksPath(ReadingScope scope) =>
      'users/${scope.uid}/children/${scope.childId}/bookmarks';

  @override
  Stream<Map<String, BookBookmark>> watchBookmarks(ReadingScope scope) =>
      _firestore
          .collection(_bookmarksPath(scope))
          .snapshots()
          .map(
            (snapshot) => {
              for (final doc in snapshot.docs)
                doc.id: ?bookmarkFromMap(doc.data()),
            },
          );

  @override
  Future<BookBookmark?> loadBookmark(ReadingScope scope, String bookId) async {
    final doc = await _firestore
        .doc('${_bookmarksPath(scope)}/$bookId')
        .get(const GetOptions(source: Source.server));
    return bookmarkFromMap(doc.data() ?? {});
  }

  @override
  Future<void> saveBookmark(
    ReadingScope scope,
    Book book,
    int pageIndex,
  ) async {
    await _functions.httpsCallable('saveBookBookmark').call({
      'childId': scope.childId,
      'bookId': book.id,
      'contentVersion': book.contentVersion,
      'pageIndex': pageIndex,
    });
  }
}

Book? bookFromMap(String id, Map<String, dynamic> data) {
  final title = data['title'];
  final description = data['description'];
  final coverKey = data['coverKey'];
  final count = data['pageCount'];
  final version = data['contentVersion'];
  final order = data['order'];
  final access = data['access'];
  if (data['published'] != true ||
      data['schemaVersion'] != 1 ||
      title is! String ||
      title.trim().isEmpty ||
      title.length > 100 ||
      description is! String ||
      description.trim().isEmpty ||
      description.length > 300 ||
      coverKey is! String ||
      coverKey.isEmpty ||
      count is! int ||
      count < 1 ||
      count > 40 ||
      version is! int ||
      version < 1 ||
      order is! int ||
      order < 0 ||
      (access != 'free' && access != 'premium') ||
      data.containsKey('pages')) {
    return null;
  }
  return Book(
    id: id,
    title: title,
    description: description,
    coverKey: coverKey,
    pageCount: count,
    access: access == 'free' ? BookAccess.free : BookAccess.premium,
    contentVersion: version,
    order: order,
  );
}

BookContent bookContentFromMap(Book book, Map<String, dynamic> data) {
  final rawPages = data['pages'];
  if (data['published'] != true ||
      data['schemaVersion'] != 1 ||
      data['contentVersion'] != book.contentVersion ||
      rawPages is! List ||
      rawPages.length != book.pageCount) {
    throw const BookFailure(
      'Esta história está sendo atualizada. Tente novamente.',
    );
  }
  final pages = <BookPage>[];
  final ids = <String>{};
  for (final raw in rawPages) {
    if (raw is! Map ||
        raw['id'] is! String ||
        raw['text'] is! String ||
        (raw['text'] as String).trim().isEmpty ||
        (raw['text'] as String).length > 1200 ||
        raw['illustration'] is! String ||
        !ids.add(raw['id'] as String)) {
      throw const BookFailure(
        'Não foi possível carregar as páginas desta história.',
      );
    }
    pages.add(
      BookPage(
        id: raw['id'] as String,
        text: raw['text'] as String,
        illustration: raw['illustration'] as String,
      ),
    );
  }
  return BookContent(book: book, pages: List.unmodifiable(pages));
}

BookBookmark? bookmarkFromMap(Map<String, dynamic> data) {
  final index = data['pageIndex'];
  final version = data['contentVersion'];
  if (index is! int || index < 0 || version is! int || version < 1) return null;
  return BookBookmark(pageIndex: index, contentVersion: version);
}

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  if (AppConfig.useFirebase) {
    return FirestoreBookRepository(
      ref.watch(firestoreProvider),
      ref.watch(functionsProvider),
    );
  }
  final repository = LocalBookRepository(ref.watch(sharedPreferencesProvider));
  ref.onDispose(repository.dispose);
  return repository;
});
