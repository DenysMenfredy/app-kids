import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/storage/local_storage.dart';
import '../data/profile_sync_service.dart';
import '../domain/child_profile.dart';
import '../domain/child_record.dart';

/// Who the app is being used by: the parent and the child profile.
///
/// Deliberately no XP, coins or streak. Those are the backend's to mint
/// (ADR 0003), and keeping a copy here meant persisting numbers that, with
/// the backend on, no screen ever read — see [DemoProgress].
class SessionState extends Equatable {
  const SessionState({
    required this.parentName,
    required this.child,
    required this.childId,
  });

  final String parentName;
  final ChildProfile child;
  final String childId;

  static const initial = SessionState(
    parentName: 'Ana',
    child: ChildProfile.defaultProfile,
    childId: AppConfig.primaryChildId,
  );

  SessionState copyWith({
    String? parentName,
    ChildProfile? child,
    String? childId,
  }) {
    return SessionState(
      parentName: parentName ?? this.parentName,
      child: child ?? this.child,
      childId: childId ?? this.childId,
    );
  }

  @override
  List<Object?> get props => [parentName, child, childId];
}

class SessionController extends Notifier<SessionState> {
  static const _keyParentName = 'parentName';
  static const _keyChildName = 'childName';
  static const _keyChildAge = 'childAge';
  static const _keyChildAvatar = 'childAvatar';
  static const _keyChildId = 'childId';
  static const _keyChildCreateRequestId = 'childCreateRequestId';

  @override
  SessionState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final scope = ref.watch(sessionStorageScopeProvider);
    const initial = SessionState.initial;
    final avatarIndex =
        prefs.getInt(_key(scope, _keyChildAvatar)) ??
        initial.child.avatar.index;
    return SessionState(
      parentName:
          prefs.getString(_key(scope, _keyParentName)) ?? initial.parentName,
      child: ChildProfile(
        name: prefs.getString(_key(scope, _keyChildName)) ?? initial.child.name,
        age: prefs.getInt(_key(scope, _keyChildAge)) ?? initial.child.age,
        avatar: ChildAvatar
            .values[avatarIndex.clamp(0, ChildAvatar.values.length - 1)],
      ),
      childId: prefs.getString(_key(scope, _keyChildId)) ?? initial.childId,
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

  Future<void> saveChildProfile(
    ChildProfile profile, {
    bool createNew = false,
    String? requestId,
  }) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final scope = ref.read(sessionStorageScopeProvider);
    final requestIdKey = _key(scope, _keyChildCreateRequestId);
    final operationId =
        requestId ??
        prefs.getString(requestIdKey) ??
        DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    if (requestId == null) await prefs.setString(requestIdKey, operationId);

    final sync = ref.read(profileSyncServiceProvider);
    final savedChildId = await sync.saveChildProfile(
      profile: profile,
      requestId: operationId,
      existingChildId: createNew ? null : state.childId,
    );
    state = state.copyWith(child: profile, childId: savedChildId);
    _persist();
    if (requestId == null) await prefs.remove(requestIdKey);
    unawaited(sync.syncOnboardingState('child_profile_created'));
  }

  void selectChild(ChildRecord child) {
    state = state.copyWith(child: child.profile, childId: child.id);
    _persist();
  }

  /// Clears a removed selection after the server confirms no child profiles
  /// remain for this parent. The placeholder ID is never treated as a
  /// server-issued child; creating a profile still goes through the backend.
  void resetChildSelection() {
    state = state.copyWith(
      child: ChildProfile.defaultProfile,
      childId: AppConfig.primaryChildId,
    );
    _persist();
  }

  void _persist() {
    final prefs = ref.read(sharedPreferencesProvider);
    final scope = ref.read(sessionStorageScopeProvider);
    prefs
      ..setString(_key(scope, _keyParentName), state.parentName)
      ..setString(_key(scope, _keyChildName), state.child.name)
      ..setInt(_key(scope, _keyChildAge), state.child.age)
      ..setInt(_key(scope, _keyChildAvatar), state.child.avatar.index)
      ..setString(_key(scope, _keyChildId), state.childId);
  }

  String _key(String scope, String field) {
    // Preserve the existing anonymous/demo cache. Firebase-backed profiles
    // use a separate namespace for each authenticated parent.
    if (scope == 'demo') return 'session.$field';
    return 'session.$scope.$field';
  }
}

/// Selects the local profile cache for the active parent. Watching Firebase
/// auth makes SessionController rebuild when the account changes; reading
/// currentUser gives the just-updated UID before relying on a prior cache.
final sessionStorageScopeProvider = Provider<String>((ref) {
  if (!AppConfig.useFirebase) return 'demo';
  ref.watch(firebaseAuthUserProvider);
  return ref.read(firebaseAuthProvider).currentUser?.uid ?? 'signed-out';
});

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
