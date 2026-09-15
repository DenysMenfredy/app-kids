import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';
import 'session_controller.dart';

/// The child's gamification totals as displayed in the app.
class Progress extends Equatable {
  const Progress({required this.xp, required this.coins, required this.streak});

  final int xp;
  final int coins;
  final int streak;

  static const zero = Progress(xp: 0, coins: 0, streak: 0);

  @override
  List<Object?> get props => [xp, coins, streak];
}

/// Streams `users/{uid}/gamification/{childId}` — the document only
/// completeLesson writes (ADR 0003). A child who has never finished a
/// lesson has no document yet, which reads as zero.
final remoteProgressProvider = StreamProvider<Progress>((ref) {
  if (!AppConfig.useFirebase) {
    return Stream.value(Progress.zero);
  }
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);

  return auth.authStateChanges().asyncExpand((user) {
    if (user == null) return Stream.value(Progress.zero);
    return firestore
        .doc('users/${user.uid}/gamification/${AppConfig.primaryChildId}')
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (data == null) return Progress.zero;
          return Progress(
            xp: (data['xp'] as num?)?.toInt() ?? 0,
            coins: (data['coins'] as num?)?.toInt() ?? 0,
            streak: (data['streak'] as num?)?.toInt() ?? 0,
          );
        });
  });
});

/// XP, coins and streak for the UI.
///
/// In Firebase mode these are the backend's numbers — the app displays what
/// it is told and never adds to them locally. Demo mode falls back to the
/// on-device session values so the prototype still works offline.
final progressProvider = Provider<Progress>((ref) {
  if (!AppConfig.useFirebase) {
    final session = ref.watch(sessionProvider);
    return Progress(
      xp: session.xp,
      coins: session.coins,
      streak: session.streak,
    );
  }
  // While a refresh is in flight Riverpod keeps the previous value, so the
  // numbers don't flicker back to zero between snapshots.
  return ref.watch(remoteProgressProvider).value ?? Progress.zero;
});
