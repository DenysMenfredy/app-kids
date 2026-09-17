import 'package:equatable/equatable.dart';

/// A book in the child's library.
///
/// Carries what the book *is*. How its cover is painted lives in
/// `presentation/book_cover_style.dart`, keyed by [id] — a colour on a
/// domain model is a decision the backend would have no way to express when
/// this catalog stops being hardcoded.
class Book extends Equatable {
  const Book({
    required this.id,
    required this.title,
    required this.initial,
    this.locked = false,
    this.isNew = false,
    this.unlockHint,
  });

  final String id;
  final String title;

  /// Large letter shown on the cover.
  final String initial;

  final bool locked;
  final bool isNew;
  final String? unlockHint;

  @override
  List<Object?> get props => [id, title, initial, locked, isNew, unlockHint];
}

const bookLibrary = [
  Book(id: 'sapo', title: 'O Sapo Bocudo', initial: 'S', isNew: true),
  Book(id: 'vogais', title: 'A Festa das Vogais', initial: 'A'),
  Book(
    id: 'bicho',
    title: 'Bicho de Letra',
    initial: 'B',
    locked: true,
    unlockHint: '3 lições',
  ),
  Book(
    id: 'trem',
    title: 'O Trem das Sílabas',
    initial: 'T',
    locked: true,
    unlockHint: '5 lições',
  ),
  Book(
    id: 'rimas',
    title: 'Rimas da Floresta',
    initial: 'R',
    locked: true,
    unlockHint: '8 lições',
  ),
  Book(
    id: 'historia',
    title: 'Minha 1ª História',
    initial: 'H',
    locked: true,
    unlockHint: 'Módulo 7',
  ),
];
