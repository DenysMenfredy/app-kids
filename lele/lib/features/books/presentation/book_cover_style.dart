import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/book.dart';

class BookCover {
  const BookCover({required this.gradient, required this.spine});
  final List<Color> gradient;
  final Color spine;
}

const bookCovers = <String, BookCover>{
  'frog': BookCover(
    gradient: [AppColors.teal, AppColors.tealBright],
    spine: AppColors.tealDark,
  ),
  'vowels': BookCover(
    gradient: [AppColors.orangeSoft, Color(0xFFFFB98A)],
    spine: AppColors.orangeDark,
  ),
  'cat': BookCover(
    gradient: [AppColors.purple, AppColors.purpleBright],
    spine: AppColors.purpleDark,
  ),
  'train': BookCover(
    gradient: [AppColors.yellow, AppColors.yellowBright],
    spine: AppColors.yellowDark,
  ),
  'flowers': BookCover(
    gradient: [AppColors.red, AppColors.redBright],
    spine: AppColors.redDark,
  ),
  'book': BookCover(
    gradient: [AppColors.purple, AppColors.teal],
    spine: AppColors.purpleDark,
  ),
};

const defaultBookCover = BookCover(
  gradient: [AppColors.teal, AppColors.tealBright],
  spine: AppColors.tealDark,
);

BookCover coverOf(Book book) => bookCovers[book.coverKey] ?? defaultBookCover;
