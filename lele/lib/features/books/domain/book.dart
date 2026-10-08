import 'package:equatable/equatable.dart';

enum BookAccess { free, premium }

typedef ReadingScope = ({String uid, String childId});

/// Published catalog metadata; protected page text is loaded separately.
class Book extends Equatable {
  const Book({
    required this.id,
    required this.title,
    required this.description,
    required this.coverKey,
    required this.pageCount,
    required this.access,
    required this.contentVersion,
    required this.order,
  });

  final String id;
  final String title;
  final String description;
  final String coverKey;
  final int pageCount;
  final BookAccess access;
  final int contentVersion;
  final int order;

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    coverKey,
    pageCount,
    access,
    contentVersion,
    order,
  ];
}

class BookPage extends Equatable {
  const BookPage({
    required this.id,
    required this.text,
    required this.illustration,
  });
  final String id;
  final String text;
  final String illustration;
  @override
  List<Object?> get props => [id, text, illustration];
}

class BookContent {
  const BookContent({required this.book, required this.pages});
  final Book book;
  final List<BookPage> pages;
}

/// Navigation state only; this never grants learning rewards.
class BookBookmark {
  const BookBookmark({required this.pageIndex, required this.contentVersion});
  final int pageIndex;
  final int contentVersion;
}

class BookFailure implements Exception {
  const BookFailure(this.message, {this.premiumRequired = false});
  final String message;
  final bool premiumRequired;
}
