import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_router.dart';
import '../domain/lesson.dart';

/// Orders the daily lesson activities and maps each one to its route and
/// progress-bar value. Adding a new activity only requires extending
/// [todaysLesson] and this table.
class LessonFlow {
  const LessonFlow();

  static const _routes = {
    ActivityType.tap: AppRoutes.activityTap,
    ActivityType.match: AppRoutes.activityMatch,
    ActivityType.trace: AppRoutes.activityTrace,
    ActivityType.listen: AppRoutes.activityListen,
  };

  static const _progress = {
    ActivityType.tap: 0.25,
    ActivityType.match: 0.50,
    ActivityType.trace: 0.75,
    ActivityType.listen: 0.95,
  };

  String get firstRoute => _routes[todaysLesson.first.type]!;

  double progressOf(ActivityType type) => _progress[type]!;

  /// Route of the activity after [type], or the reward screen at the end.
  String nextRoute(ActivityType type) {
    final index = todaysLesson.indexWhere((a) => a.type == type);
    final isLast = index == todaysLesson.length - 1;
    return isLast
        ? AppRoutes.reward
        : _routes[todaysLesson[index + 1].type]!;
  }
}

final lessonFlowProvider = Provider<LessonFlow>((ref) => const LessonFlow());
