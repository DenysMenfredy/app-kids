import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/child_profile.dart';

/// Syncs parent metadata and persists child profiles. Parent metadata is
/// best-effort; profile saves are awaited because learning requires a
/// server-issued child ID before the app can proceed.
abstract interface class ProfileSyncService {
  Future<void> syncParentName(String name);

  Future<String> saveChildProfile({
    required ChildProfile profile,
    required String requestId,
    required String? existingChildId,
  });

  Future<void> syncOnboardingState(String state);
}

class NoopProfileSyncService implements ProfileSyncService {
  const NoopProfileSyncService();

  @override
  Future<void> syncParentName(String name) async {}

  @override
  Future<String> saveChildProfile({
    required ChildProfile profile,
    required String requestId,
    required String? existingChildId,
  }) async => AppConfig.primaryChildId;

  @override
  Future<void> syncOnboardingState(String state) async {}
}

class FirestoreProfileSyncService implements ProfileSyncService {
  FirestoreProfileSyncService(this._auth, this._firestore, this._functions);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

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
  Future<String> saveChildProfile({
    required ChildProfile profile,
    required String requestId,
    required String? existingChildId,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('A parent must be signed in.');

    if (existingChildId != null) {
      final existingRef = _firestore.doc(
        'users/$uid/children/$existingChildId',
      );
      if ((await existingRef.get()).exists) {
        await existingRef.set(
          _editableFields(profile),
          SetOptions(merge: true),
        );
        return existingChildId;
      }
    }

    final result = await _functions
        .httpsCallable('createChildProfile')
        .call<dynamic>({
          'requestId': requestId,
          'profile': {
            'name': profile.name,
            'age': profile.age,
            'avatarId': profile.avatar.name,
          },
        });
    final data = result.data;
    if (data is! Map || data['childId'] is! String) {
      throw StateError('createChildProfile returned no child ID.');
    }
    return data['childId'] as String;
  }

  Map<String, Object?> _editableFields(ChildProfile profile) => {
    // Minimum child data only (spec §19): name, age, avatar.
    'name': profile.name,
    'age': profile.age,
    'avatarId': profile.avatar.name,
    'updatedAt': FieldValue.serverTimestamp(),
  };

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
      ref.watch(functionsProvider),
    );
  }
  return const NoopProfileSyncService();
});
