import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_router.dart';
import '../domain/lesson.dart';
import 'lesson_content_provider.dart';

/// Orders the daily lesson activities and maps each one to its route and
/// progress-bar value. The play order is [ActivityType]'s own order, which
/// the backend's seed content is validated against.
class LessonFlow {
  const LessonFlow({this.hasStory = false});
  final bool hasStory;

  static const _routes = {
    ActivityType.tap: AppRoutes.activityTap,
    ActivityType.match: AppRoutes.activityMatch,
    ActivityType.trace: AppRoutes.activityTrace,
    ActivityType.listen: AppRoutes.activityListen,
    ActivityType.story: AppRoutes.activityStory,
  };

  static const _progress = {
    ActivityType.tap: 0.25,
    ActivityType.match: 0.50,
    ActivityType.trace: 0.75,
    ActivityType.listen: 0.95,
    ActivityType.story: 1.0,
  };

  String get firstRoute => _routes[ActivityType.values.first]!;

  String routeOf(ActivityType type) => _routes[type]!;

  double progressOf(ActivityType type) =>
      hasStory ? (ActivityType.values.indexOf(type) + 1) / 5 : _progress[type]!;

  /// Route of the activity after [type], or the reward screen at the end.
  String nextRoute(ActivityType type) {
    if (type == ActivityType.story ||
        (type == ActivityType.listen && !hasStory)) {
      return AppRoutes.reward;
    }
    final index = ActivityType.values.indexOf(type);
    return _routes[ActivityType.values[index + 1]]!;
  }
}

final lessonFlowProvider = Provider<LessonFlow>(
  (ref) => LessonFlow(
    hasStory: ref.watch(currentLessonContentProvider).value?.story != null,
  ),
);
