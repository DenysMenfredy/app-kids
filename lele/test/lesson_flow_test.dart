import 'package:flutter_test/flutter_test.dart';
import 'package:lele/app/router/app_router.dart';
import 'package:lele/features/lesson/application/lesson_controller.dart';
import 'package:lele/features/lesson/domain/lesson.dart';

void main() {
  const flow = LessonFlow();

  group('LessonFlow', () {
    test('starts with the tap activity', () {
      expect(flow.firstRoute, AppRoutes.activityTap);
    });

    test('chains activities in order and ends at the reward', () {
      expect(flow.nextRoute(ActivityType.tap), AppRoutes.activityMatch);
      expect(flow.nextRoute(ActivityType.match), AppRoutes.activityTrace);
      expect(flow.nextRoute(ActivityType.trace), AppRoutes.activityListen);
      expect(flow.nextRoute(ActivityType.listen), AppRoutes.reward);
    });

    test('progress grows monotonically through the lesson', () {
      final values = ActivityType.values
          .map((type) => flow.progressOf(type))
          .toList();
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
      }
    });
  });
}
