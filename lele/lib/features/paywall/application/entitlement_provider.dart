import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';

/// Whether the family currently has Premium.
///
/// Firebase mode streams `users/{uid}/entitlements/premium` — the document
/// only trusted backend code writes (spec §7). Any read problem yields
/// `false`: premium authorization fails safely (spec §20).
final premiumActiveProvider = StreamProvider<bool>((ref) {
  if (!AppConfig.useFirebase) {
    return Stream.value(false);
  }
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);

  return auth.authStateChanges().asyncExpand((user) {
    if (user == null) return Stream.value(false);
    return firestore
        .doc('users/${user.uid}/entitlements/premium')
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          final validFromValue = data?['validFrom'];
          final validUntilValue = data?['validUntil'];
          final validFrom = validFromValue is Timestamp ? validFromValue : null;
          final validUntil = validUntilValue is Timestamp
              ? validUntilValue
              : null;
          final features = data?['features'];
          final now = Timestamp.now();
          return data?['active'] == true &&
              features is List &&
              features.contains('full_curriculum') &&
              validFrom != null &&
              validUntil != null &&
              validFrom.compareTo(now) <= 0 &&
              validUntil.compareTo(now) > 0;
        });
  });
});

/// Convenience for widgets: unresolved/error states read as "not premium".
final isPremiumProvider = Provider<bool>(
  (ref) => ref.watch(premiumActiveProvider).value ?? false,
);
