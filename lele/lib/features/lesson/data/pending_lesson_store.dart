import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/lesson_recovery.dart';

/// Bounded, short-lived retry data, isolated by authenticated parent and child.
/// It contains references and answer evidence, never the protected lesson.
class PendingLessonStore {
  PendingLessonStore(this._preferences, this.owner, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final SharedPreferences _preferences;
  final String owner;
  final DateTime Function() _now;
  String get _prefix => 'lesson.pending.v1.$owner.';

  Future<PendingLesson?> load(String childId) async {
    try {
      final raw = _preferences.getString('$_prefix$childId');
      if (raw == null) return null;
      if (raw.length > 250000) throw const FormatException();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final created = map['createdAtMillis'];
      final version = map['contentVersion'];
      final sequence = map['lifecycleSequence'];
      final attempts = map['attempts'];
      final age = created is int ? _now().millisecondsSinceEpoch - created : -1;
      if (map['schemaVersion'] != 1 ||
          map['childId'] != childId ||
          created is! int ||
          age < 0 ||
          age > const Duration(hours: 24).inMilliseconds ||
          (version != null && (version is! int || version < 1)) ||
          sequence is! int ||
          sequence < 0 ||
          attempts is! List ||
          attempts.length > 500) {
        throw const FormatException();
      }
      return PendingLesson(
        childId: _id(map['childId']),
        lessonId: _id(map['lessonId']),
        requestId: _id(map['requestId']),
        createdAtMillis: created,
        contentVersion: version as int?,
        sessionId: map['sessionId'] == null ? null : _id(map['sessionId']),
        lifecycleSequence: sequence,
        completionRequested: map['completionRequested'] == true,
        attempts: List.unmodifiable(
          attempts.map((raw) {
            final attempt = raw as Map<String, dynamic>;
            return PendingLessonAttempt(
              requestId: _id(attempt['requestId']),
              activityId: _id(attempt['activityId']),
              response: boundedLessonResponse(attempt['response']),
            );
          }),
        ),
      );
    } catch (_) {
      await remove(childId);
      return null;
    }
  }

  Future<void> save(PendingLesson lesson) async {
    if (lesson.attempts.length > 500) {
      throw StateError('Too many pending answers');
    }
    final encoded = jsonEncode({
      'schemaVersion': 1,
      'childId': lesson.childId,
      'lessonId': lesson.lessonId,
      'requestId': lesson.requestId,
      'createdAtMillis': lesson.createdAtMillis,
      'contentVersion': lesson.contentVersion,
      'sessionId': lesson.sessionId,
      'lifecycleSequence': lesson.lifecycleSequence,
      'completionRequested': lesson.completionRequested,
      'attempts': [
        for (final attempt in lesson.attempts)
          {
            'requestId': attempt.requestId,
            'activityId': attempt.activityId,
            'response': boundedLessonResponse(attempt.response),
          },
      ],
    });
    if (encoded.length > 250000) {
      throw StateError('Pending lesson is too large');
    }
    final stored = await _preferences.setString(
      '$_prefix${lesson.childId}',
      encoded,
    );
    if (!stored) throw StateError('Pending lesson was not persisted');
  }

  Future<void> remove(String childId) async {
    if (!await _preferences.remove('$_prefix$childId')) {
      throw StateError('Pending lesson was not cleared');
    }
  }

  Future<void> clearOwner() async {
    for (final key
        in _preferences
            .getKeys()
            .where((key) => key.startsWith(_prefix))
            .toList()) {
      await _preferences.remove(key);
    }
  }
}

String _id(Object? value) {
  if (value is! String || !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(value)) {
    throw const FormatException('Invalid lesson reference');
  }
  return value;
}

/// Persist only the bounded fields the backend accepts, never arbitrary data.
Map<String, Object?> boundedLessonResponse(Object? raw) {
  if (raw is! Map) throw const FormatException('Invalid lesson answer');
  String text(String key, int limit) {
    final value = raw[key];
    if (value is! String || value.isEmpty || value.length > limit) {
      throw const FormatException('Invalid lesson answer');
    }
    return value;
  }

  if (raw['selectedLabel'] != null) {
    return Map.unmodifiable({
      'selectedLabel': text('selectedLabel', 80),
      if (raw['questionId'] != null) 'questionId': text('questionId', 64),
    });
  }
  if (raw['upper'] != null) {
    return Map.unmodifiable({
      'upper': text('upper', 16),
      'lower': text('lower', 16),
    });
  }
  int number(String key, int min, int max) {
    final value = raw[key];
    if (value is! int || value < min || value > max) {
      throw const FormatException('Invalid lesson evidence');
    }
    return value;
  }

  return Map.unmodifiable({
    'strokeCount': number('strokeCount', 1, 20),
    'pointCount': number('pointCount', 2, 1000),
    'durationMillis': number('durationMillis', 100, 120000),
  });
}
