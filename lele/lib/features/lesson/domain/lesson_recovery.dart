/// A local pointer is only a recovery hint; the server confirms all progress.
class PendingLesson {
  const PendingLesson({
    required this.childId,
    required this.lessonId,
    required this.requestId,
    required this.createdAtMillis,
    this.contentVersion,
    this.sessionId,
    this.lifecycleSequence = 0,
    this.attempts = const [],
    this.completionRequested = false,
  });

  final String childId;
  final String lessonId;
  final String requestId;
  final int createdAtMillis;
  final int? contentVersion;
  final String? sessionId;
  final int lifecycleSequence;
  final List<PendingLessonAttempt> attempts;
  final bool completionRequested;

  PendingLesson copyWith({
    String? sessionId,
    int? lifecycleSequence,
    List<PendingLessonAttempt>? attempts,
    bool? completionRequested,
  }) => PendingLesson(
    childId: childId,
    lessonId: lessonId,
    requestId: requestId,
    createdAtMillis: createdAtMillis,
    contentVersion: contentVersion,
    sessionId: sessionId ?? this.sessionId,
    lifecycleSequence: lifecycleSequence ?? this.lifecycleSequence,
    attempts: attempts ?? this.attempts,
    completionRequested: completionRequested ?? this.completionRequested,
  );
}

class PendingLessonAttempt {
  const PendingLessonAttempt({
    required this.requestId,
    required this.activityId,
    required this.response,
  });
  final String requestId;
  final String activityId;
  final Map<String, Object?> response;
}

/// Confirmed progress returned by the recovery callable after authorization.
class LessonRecovery {
  const LessonRecovery({
    required this.lessonId,
    required this.nextActivityIndex,
    required this.completedItems,
    required this.correctAnswers,
    required this.wrongAnswers,
  });
  final String lessonId;
  final int nextActivityIndex;
  final Map<String, Set<String>> completedItems;
  final int correctAnswers;
  final int wrongAnswers;
}
