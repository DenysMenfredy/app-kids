import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// The four activity types of the MVP daily lesson, in play order.
enum ActivityType { tap, match, trace, listen }

class LessonActivity extends Equatable {
  const LessonActivity({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.icon,
    required this.chipColor,
  });

  final ActivityType type;
  final String title;
  final String subtitle;
  final String duration;
  final IconData icon;
  final Color chipColor;

  @override
  List<Object?> get props => [type, title, subtitle, duration];
}

const todaysLesson = [
  LessonActivity(
    type: ActivityType.tap,
    title: 'Toque na letra',
    subtitle: 'Encontre a letra certa',
    duration: '~1 min',
    icon: Icons.touch_app_rounded,
    chipColor: AppColors.orangeSoft,
  ),
  LessonActivity(
    type: ActivityType.match,
    title: 'Ligue as letras',
    subtitle: 'Maiúsculas e minúsculas',
    duration: '~2 min',
    icon: Icons.swap_horiz_rounded,
    chipColor: AppColors.teal,
  ),
  LessonActivity(
    type: ActivityType.trace,
    title: 'Trace a letra',
    subtitle: 'Desenhe com o dedo',
    duration: '~2 min',
    icon: Icons.edit_rounded,
    chipColor: AppColors.purple,
  ),
  LessonActivity(
    type: ActivityType.listen,
    title: 'Escute e escolha',
    subtitle: 'Qual palavra você ouviu?',
    duration: '~1 min',
    icon: Icons.music_note_rounded,
    chipColor: AppColors.yellow,
  ),
];
