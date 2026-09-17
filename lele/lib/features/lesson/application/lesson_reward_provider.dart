import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/lesson_reward.dart';

/// The reward from the lesson just finished, handed to the reward screen.
class LastLessonReward extends Notifier<LessonReward?> {
  @override
  LessonReward? build() => null;

  void set(LessonReward? reward) => state = reward;
}

final lastLessonRewardProvider =
    NotifierProvider<LastLessonReward, LessonReward?>(LastLessonReward.new);
