import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class Book extends Equatable {
  const Book({
    required this.title,
    required this.initial,
    required this.coverColors,
    required this.spineColor,
    this.locked = false,
    this.isNew = false,
    this.unlockHint,
  });

  final String title;

  /// Large letter shown on the cover.
  final String initial;
  final List<Color> coverColors;
  final Color spineColor;
  final bool locked;
  final bool isNew;
  final String? unlockHint;

  @override
  List<Object?> get props => [title, initial, locked, isNew, unlockHint];
}

const bookLibrary = [
  Book(
    title: 'O Sapo Bocudo',
    initial: 'S',
    coverColors: [AppColors.teal, AppColors.tealBright],
    spineColor: AppColors.tealDark,
    isNew: true,
  ),
  Book(
    title: 'A Festa das Vogais',
    initial: 'A',
    coverColors: [AppColors.orangeSoft, Color(0xFFFFB98A)],
    spineColor: AppColors.orangeDark,
  ),
  Book(
    title: 'Bicho de Letra',
    initial: 'B',
    coverColors: [AppColors.purple, AppColors.purpleBright],
    spineColor: AppColors.purpleDark,
    locked: true,
    unlockHint: '3 lições',
  ),
  Book(
    title: 'O Trem das Sílabas',
    initial: 'T',
    coverColors: [AppColors.yellow, AppColors.yellowBright],
    spineColor: AppColors.yellowDark,
    locked: true,
    unlockHint: '5 lições',
  ),
  Book(
    title: 'Rimas da Floresta',
    initial: 'R',
    coverColors: [AppColors.red, AppColors.redBright],
    spineColor: AppColors.redDark,
    locked: true,
    unlockHint: '8 lições',
  ),
  Book(
    title: 'Minha 1ª História',
    initial: 'H',
    coverColors: [AppColors.textDark, AppColors.brownDeep],
    spineColor: AppColors.brownDarkest,
    locked: true,
    unlockHint: 'Módulo 7',
  ),
];
