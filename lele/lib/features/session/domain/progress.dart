import 'package:equatable/equatable.dart';

/// The child's gamification totals as displayed in the app.
class Progress extends Equatable {
  const Progress({required this.xp, required this.coins, required this.streak});

  final int xp;
  final int coins;
  final int streak;

  static const zero = Progress(xp: 0, coins: 0, streak: 0);

  Progress copyWith({int? xp, int? coins, int? streak}) => Progress(
    xp: xp ?? this.xp,
    coins: coins ?? this.coins,
    streak: streak ?? this.streak,
  );

  @override
  List<Object?> get props => [xp, coins, streak];
}
