import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';

/// Whether the family currently has Premium.
///
/// Firebase mode streams `users/{uid}/entitlements/premium` — the document
/// only trusted backend code writes (spec §7). Any read problem yields
/// `false`: premium authorization fails safely (spec §20).
final premiumActiveProvider = Provider<AsyncValue<bool>>(
  (ref) => _featureState(ref, 'full_curriculum'),
);

final premiumBooksActiveProvider = Provider<AsyncValue<bool>>(
  (ref) => _featureState(ref, 'premium_books'),
);

AsyncValue<bool> _featureState(Ref ref, String feature) {
  if (!AppConfig.useFirebase) return const AsyncData(false);

  final authState = ref.watch(firebaseAuthUserProvider);
  if (authState.isLoading) return const AsyncLoading();
  if (authState.hasError) {
    return AsyncError(authState.error!, authState.stackTrace!);
  }
  final user = authState.value;
  if (user == null) return const AsyncData(false);

  return ref.watch(_premiumForUidProvider((uid: user.uid, feature: feature)));
}

final _premiumForUidProvider = StreamProvider.autoDispose
    .family<bool, ({String uid, String feature})>((ref, scope) {
      final firestore = ref.watch(firestoreProvider);
      final stream = StreamController<bool>();
      Timer? boundaryTimer;
      void emitAccess(Map<String, dynamic>? data) {
        boundaryTimer?.cancel();
        final validFromValue = data?['validFrom'];
        final validUntilValue = data?['validUntil'];
        final validFrom = validFromValue is Timestamp ? validFromValue : null;
        final validUntil = validUntilValue is Timestamp
            ? validUntilValue
            : null;
        final features = data?['features'];
        final now = Timestamp.now();
        stream.add(
          data?['active'] == true &&
              features is List &&
              features.contains(scope.feature) &&
              validFrom != null &&
              validUntil != null &&
              validFrom.compareTo(now) <= 0 &&
              validUntil.compareTo(now) > 0,
        );
        // Access expires even when Firestore has no new document snapshot.
        final boundaries =
            [validFrom, validUntil]
                .whereType<Timestamp>()
                .where((time) => time.compareTo(now) > 0)
                .toList()
              ..sort();
        if (boundaries.isNotEmpty) {
          boundaryTimer = Timer(
            boundaries.first.toDate().difference(now.toDate()),
            () => emitAccess(data),
          );
        }
      }

      final subscription = firestore
          .doc('users/${scope.uid}/entitlements/premium')
          .snapshots()
          .listen(
            (snapshot) => emitAccess(snapshot.data()),
            onError: (Object error, StackTrace stack) {
              boundaryTimer?.cancel();
              stream.addError(error, stack);
            },
          );
      ref.onDispose(() {
        boundaryTimer?.cancel();
        unawaited(subscription.cancel());
        unawaited(stream.close());
      });
      return stream.stream;
    });

/// Convenience for widgets: unresolved/error states read as "not premium".
final isPremiumProvider = Provider<bool>((ref) {
  final state = ref.watch(premiumActiveProvider);
  if (state.isLoading || state.hasError) return false;
  return state.value ?? false;
});
