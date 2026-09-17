import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/book.dart';

/// How one book's cover is painted.
class BookCover {
  const BookCover({required this.gradient, required this.spine});

  /// Front-to-back of the cover gradient.
  final List<Color> gradient;

  /// The darker edge that reads as the book's spine.
  final Color spine;
}

/// Cover art per [Book.id]. Missing entries fall back to [defaultBookCover]
/// rather than throwing, so a book the backend adds still renders.
const bookCovers = <String, BookCover>{
  'sapo': BookCover(
    gradient: [AppColors.teal, AppColors.tealBright],
    spine: AppColors.tealDark,
  ),
  'vogais': BookCover(
    gradient: [AppColors.orangeSoft, Color(0xFFFFB98A)],
    spine: AppColors.orangeDark,
  ),
  'bicho': BookCover(
    gradient: [AppColors.purple, AppColors.purpleBright],
    spine: AppColors.purpleDark,
  ),
  'trem': BookCover(
    gradient: [AppColors.yellow, AppColors.yellowBright],
    spine: AppColors.yellowDark,
  ),
  'rimas': BookCover(
    gradient: [AppColors.red, AppColors.redBright],
    spine: AppColors.redDark,
  ),
  'historia': BookCover(
    gradient: [AppColors.textDark, AppColors.brownDeep],
    spine: AppColors.brownDarkest,
  ),
};

const defaultBookCover = BookCover(
  gradient: [AppColors.teal, AppColors.tealBright],
  spine: AppColors.tealDark,
);

BookCover coverOf(Book book) => bookCovers[book.id] ?? defaultBookCover;
