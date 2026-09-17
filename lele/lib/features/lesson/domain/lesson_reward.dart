import 'package:equatable/equatable.dart';

/// What the backend granted for a finished lesson (ADR 0003). `awarded` is
/// false when the lesson had already been completed — replaying it refreshes
/// the stats but grants nothing, so the reward screen shows no deltas.
class LessonReward extends Equatable {
  const LessonReward({
    required this.awarded,
    required this.xpEarned,
    required this.coinsEarned,
    required this.xp,
    required this.coins,
    required this.streak,
  });

  final bool awarded;
  final int xpEarned;
  final int coinsEarned;
  final int xp;
  final int coins;
  final int streak;

  /// Demo-mode rewards, matching the backend's constants.
  static const demo = LessonReward(
    awarded: true,
    xpEarned: 50,
    coinsEarned: 10,
    xp: 0,
    coins: 0,
    streak: 0,
  );

  factory LessonReward.fromMap(Map<String, dynamic> map) {
    int intOf(String key) => (map[key] as num?)?.toInt() ?? 0;
    return LessonReward(
      awarded: map['awarded'] == true,
      xpEarned: intOf('xpEarned'),
      coinsEarned: intOf('coinsEarned'),
      xp: intOf('xp'),
      coins: intOf('coins'),
      streak: intOf('streak'),
    );
  }

  @override
  List<Object?> get props => [
    awarded,
    xpEarned,
    coinsEarned,
    xp,
    coins,
    streak,
  ];
}
