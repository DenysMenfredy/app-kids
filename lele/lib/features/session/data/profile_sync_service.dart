import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/child_profile.dart';

/// Mirrors locally-held profile state into the backend. Sync is
/// best-effort and never blocks the UI: the local store remains the source
/// of immediate truth, Firestore is the durable copy (spec §20: tolerate
/// temporary offline conditions for non-sensitive interactions).
abstract interface class ProfileSyncService {
  Future<void> syncParentName(String name);

  Future<void> syncChildProfile(ChildProfile child);

  Future<void> syncOnboardingState(String state);
}

class NoopProfileSyncService implements ProfileSyncService {
  const NoopProfileSyncService();

  @override
  Future<void> syncParentName(String name) async {}

  @override
  Future<void> syncChildProfile(ChildProfile child) async {}

  @override
  Future<void> syncOnboardingState(String state) async {}
}

class FirestoreProfileSyncService implements ProfileSyncService {
  FirestoreProfileSyncService(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String? get _uid => _auth.currentUser?.uid;

  @override
  Future<void> syncParentName(String name) {
    return _tolerant('syncParentName', (uid) async {
      await _firestore.doc('users/$uid').set({
        'displayName': name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  @override
  Future<void> syncChildProfile(ChildProfile child) {
    return _tolerant('syncChildProfile', (uid) async {
      // Minimum child data only (spec §19): name, age, avatar.
      await _firestore
          .doc('users/$uid/children/${AppConfig.primaryChildId}')
          .set({
        'name': child.name,
        'age': child.age,
        'avatarId': child.avatar.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  @override
  Future<void> syncOnboardingState(String state) {
    return _tolerant('syncOnboardingState', (uid) async {
      await _firestore.doc('users/$uid').set({
        'onboardingState': state,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> _tolerant(
    String operation,
    Future<void> Function(String uid) action,
  ) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await action(uid);
    } catch (error) {
      // Offline or transient backend error — local state stays authoritative
      // for the session; the next successful sync catches up.
      debugPrint('profile sync failed ($operation): $error');
    }
  }
}

final profileSyncServiceProvider = Provider<ProfileSyncService>((ref) {
  if (AppConfig.useFirebase) {
    return FirestoreProfileSyncService(
      ref.watch(firebaseAuthProvider),
      ref.watch(firestoreProvider),
    );
  }
  return const NoopProfileSyncService();
});
