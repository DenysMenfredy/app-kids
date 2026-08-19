import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';
import '../data/profile_sync_service.dart';
import '../domain/child_profile.dart';

/// Everything the app knows about the current family: parent, child profile
/// and the child's gamification progress. Persisted locally so progress
/// survives restarts; a backend sync layer can replace the storage later.
class SessionState extends Equatable {
  const SessionState({
    required this.parentName,
    required this.child,
    required this.xp,
    required this.coins,
    required this.streak,
  });

  final String parentName;
  final ChildProfile child;
  final int xp;
  final int coins;
  final int streak;

  static const initial = SessionState(
    parentName: 'Ana',
    child: ChildProfile.defaultProfile,
    xp: 120,
    coins: 45,
    streak: 3,
  );

  SessionState copyWith({
    String? parentName,
    ChildProfile? child,
    int? xp,
    int? coins,
    int? streak,
  }) {
    return SessionState(
      parentName: parentName ?? this.parentName,
      child: child ?? this.child,
      xp: xp ?? this.xp,
      coins: coins ?? this.coins,
      streak: streak ?? this.streak,
    );
  }

  @override
  List<Object?> get props => [parentName, child, xp, coins, streak];
}

class SessionController extends Notifier<SessionState> {
  static const _keyParentName = 'session.parentName';
  static const _keyChildName = 'session.childName';
  static const _keyChildAge = 'session.childAge';
  static const _keyChildAvatar = 'session.childAvatar';
  static const _keyXp = 'session.xp';
  static const _keyCoins = 'session.coins';
  static const _keyStreak = 'session.streak';

  @override
  SessionState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    const initial = SessionState.initial;
    final avatarIndex =
        prefs.getInt(_keyChildAvatar) ?? initial.child.avatar.index;
    return SessionState(
      parentName: prefs.getString(_keyParentName) ?? initial.parentName,
      child: ChildProfile(
        name: prefs.getString(_keyChildName) ?? initial.child.name,
        age: prefs.getInt(_keyChildAge) ?? initial.child.age,
        avatar: ChildAvatar
            .values[avatarIndex.clamp(0, ChildAvatar.values.length - 1)],
      ),
      xp: prefs.getInt(_keyXp) ?? initial.xp,
      coins: prefs.getInt(_keyCoins) ?? initial.coins,
      streak: prefs.getInt(_keyStreak) ?? initial.streak,
    );
  }

  void setParentName(String name) {
    if (name.trim().isEmpty) return;
    state = state.copyWith(parentName: name.trim());
    _persist();
    unawaited(
      ref.read(profileSyncServiceProvider).syncParentName(state.parentName),
    );
  }

  void saveChildProfile(ChildProfile profile) {
    state = state.copyWith(child: profile);
    _persist();
    final sync = ref.read(profileSyncServiceProvider);
    unawaited(sync.syncChildProfile(profile));
    unawaited(sync.syncOnboardingState('child_profile_created'));
  }

  /// Rewards granted when the daily lesson is completed.
  void completeLesson({int xpEarned = 50, int coinsEarned = 10}) {
    state = state.copyWith(
      xp: state.xp + xpEarned,
      coins: state.coins + coinsEarned,
      streak: state.streak + 1,
    );
    _persist();
  }

  void _persist() {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs
      ..setString(_keyParentName, state.parentName)
      ..setString(_keyChildName, state.child.name)
      ..setInt(_keyChildAge, state.child.age)
      ..setInt(_keyChildAvatar, state.child.avatar.index)
      ..setInt(_keyXp, state.xp)
      ..setInt(_keyCoins, state.coins)
      ..setInt(_keyStreak, state.streak);
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
