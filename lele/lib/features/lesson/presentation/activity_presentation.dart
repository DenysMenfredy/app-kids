import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/lesson.dart';

/// Chrome for an activity *kind* — its icon, colour and the summary row on
/// the lesson intro. This describes the shape of the exercise rather than
/// its content, so it stays in the app; the letters and words come from the
/// backend (`backend/seed/activities/`).
class ActivityPresentation extends Equatable {
  const ActivityPresentation({
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.icon,
    required this.chipColor,
  });

  final String title;
  final String subtitle;
  final String duration;
  final IconData icon;
  final Color chipColor;

  @override
  List<Object?> get props => [title, subtitle, duration];
}

const activityPresentation = {
  ActivityType.tap: ActivityPresentation(
    title: 'Toque na letra',
    subtitle: 'Encontre a letra certa',
    duration: '~1 min',
    icon: Icons.touch_app_rounded,
    chipColor: AppColors.orangeSoft,
  ),
  ActivityType.match: ActivityPresentation(
    title: 'Ligue as letras',
    subtitle: 'Maiúsculas e minúsculas',
    duration: '~2 min',
    icon: Icons.swap_horiz_rounded,
    chipColor: AppColors.teal,
  ),
  ActivityType.trace: ActivityPresentation(
    title: 'Trace a letra',
    subtitle: 'Desenhe com o dedo',
    duration: '~2 min',
    icon: Icons.edit_rounded,
    chipColor: AppColors.purple,
  ),
  ActivityType.listen: ActivityPresentation(
    title: 'Escute e escolha',
    subtitle: 'Qual palavra você ouviu?',
    duration: '~1 min',
    icon: Icons.music_note_rounded,
    chipColor: AppColors.yellow,
  ),
  ActivityType.story: ActivityPresentation(
    title: 'Leia uma história',
    subtitle: 'Ouça, leia e responda',
    duration: '~3 min',
    icon: Icons.auto_stories_rounded,
    chipColor: AppColors.teal,
  ),
};
