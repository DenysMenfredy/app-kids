import 'package:equatable/equatable.dart';

/// The four activity types of the daily lesson, in play order.
enum ActivityType { tap, match, trace, listen }

/// Find the letter among several.
class TapActivity extends Equatable {
  const TapActivity({
    required this.id,
    required this.instruction,
    required this.speech,
    required this.target,
    required this.options,
  });

  final String id;
  final String instruction;

  /// What the app reads aloud, with the letter named as it is spoken in
  /// pt-BR ("Toque na letra bê").
  final String speech;
  final String target;
  final List<String> options;

  @override
  List<Object?> get props => [id, instruction, speech, target, options];
}

/// Pair each uppercase letter with its lowercase form.
class MatchActivity extends Equatable {
  const MatchActivity({
    required this.id,
    required this.instruction,
    required this.hint,
    required this.uppercase,
    required this.lowercase,
  });

  final String id;
  final String instruction;
  final String hint;

  /// Left column, in display order.
  final List<String> uppercase;

  /// Right column, deliberately in a different order.
  final List<String> lowercase;

  @override
  List<Object?> get props => [id, instruction, hint, uppercase, lowercase];
}

/// Draw the letter with a finger.
class TraceActivity extends Equatable {
  const TraceActivity({
    required this.id,
    required this.instruction,
    required this.speech,
    required this.letter,
  });

  final String id;
  final String instruction;
  final String speech;
  final String letter;

  @override
  List<Object?> get props => [id, instruction, speech, letter];
}

/// Hear a word and pick it out.
class ListenActivity extends Equatable {
  const ListenActivity({
    required this.id,
    required this.instruction,
    required this.speech,
    required this.answer,
    required this.options,
  });

  final String id;
  final String instruction;

  /// The word the app speaks.
  final String speech;
  final String answer;
  final List<String> options;

  @override
  List<Object?> get props => [id, instruction, speech, answer, options];
}

/// A lesson and the exercises it plays, in order.
///
/// A lesson is exactly these four activities — the invariant the backend's
/// seed integrity tests enforce and `LessonFlow` assumes — so they are named
/// fields rather than a list that could arrive short.
class LessonContent extends Equatable {
  const LessonContent({
    required this.id,
    required this.title,
    required this.theme,
    required this.estimatedMinutes,
    required this.tap,
    required this.match,
    required this.trace,
    required this.listen,
  });

  final String id;
  final String title;
  final String theme;
  final int estimatedMinutes;
  final TapActivity tap;
  final MatchActivity match;
  final TraceActivity trace;
  final ListenActivity listen;

  @override
  List<Object?> get props => [
    id,
    title,
    theme,
    estimatedMinutes,
    tap,
    match,
    trace,
    listen,
  ];
}

/// Splits [instruction] around the first standalone occurrence of [token],
/// so the letter can be drawn in the accent colour ("Trace a letra **L** com
/// o dedo"). Null when the token isn't its own word, in which case callers
/// render the instruction plainly.
({String before, String after})? highlightSplit(
  String instruction,
  String token,
) {
  if (token.isEmpty) return null;
  final pattern = RegExp('(^|\\s)${RegExp.escape(token)}(\\s|\$)');
  final match = pattern.firstMatch(instruction);
  if (match == null) return null;
  final start = match.start + match.group(1)!.length;
  return (
    before: instruction.substring(0, start),
    after: instruction.substring(start + token.length),
  );
}
