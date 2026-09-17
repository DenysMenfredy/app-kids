import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';
import '../data/profile_sync_service.dart';
import '../domain/child_profile.dart';

/// Who the app is being used by: the parent and the child profile.
///
/// Deliberately no XP, coins or streak. Those are the backend's to mint
/// (ADR 0003), and keeping a copy here meant persisting numbers that, with
/// the backend on, no screen ever read — see [DemoProgress].
class SessionState extends Equatable {
  const SessionState({required this.parentName, required this.child});

  final String parentName;
  final ChildProfile child;

  static const initial = SessionState(
    parentName: 'Ana',
    child: ChildProfile.defaultProfile,
  );

  SessionState copyWith({String? parentName, ChildProfile? child}) {
    return SessionState(
      parentName: parentName ?? this.parentName,
      child: child ?? this.child,
    );
  }

  @override
  List<Object?> get props => [parentName, child];
}

class SessionController extends Notifier<SessionState> {
  static const _keyParentName = 'session.parentName';
  static const _keyChildName = 'session.childName';
  static const _keyChildAge = 'session.childAge';
  static const _keyChildAvatar = 'session.childAvatar';

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

  void _persist() {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs
      ..setString(_keyParentName, state.parentName)
      ..setString(_keyChildName, state.child.name)
      ..setInt(_keyChildAge, state.child.age)
      ..setInt(_keyChildAvatar, state.child.avatar.index);
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
