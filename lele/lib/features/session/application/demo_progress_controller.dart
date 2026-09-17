import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/local_storage.dart';
import '../domain/progress.dart';

/// XP, coins and the streak while the app runs with no backend.
///
/// These totals used to live on [SessionState], which persisted them on
/// every profile save — in both modes. With the backend on nothing ever read
/// them back, because `completeLesson` mints the real numbers and
/// `progressProvider` reads them from Firestore (ADR 0003). The device was
/// left holding a second copy that no screen displayed and that drifted
/// further from the truth with every lesson: 120 XP in local storage against
/// 200 on the dashboard.
///
/// So the totals live here, where they are only ever written in the one mode
/// that owns them.
class DemoProgress extends Notifier<Progress> {
  static const _keyXp = 'session.xp';
  static const _keyCoins = 'session.coins';
  static const _keyStreak = 'session.streak';

  /// Where the prototype starts, so the demo screens are not all zeros.
  static const seed = Progress(xp: 120, coins: 45, streak: 3);

  @override
  Progress build() {
    // Never consulted in Firebase mode — progressProvider goes straight to
    // the backend — but zero rather than [seed] so that a stray read can
    // never show an invented total.
    if (AppConfig.useFirebase) return Progress.zero;

    final prefs = ref.watch(sharedPreferencesProvider);
    return Progress(
      xp: prefs.getInt(_keyXp) ?? seed.xp,
      coins: prefs.getInt(_keyCoins) ?? seed.coins,
      streak: prefs.getInt(_keyStreak) ?? seed.streak,
    );
  }

  /// Demo-mode reward for finishing the daily lesson.
  void completeLesson({int xpEarned = 50, int coinsEarned = 10}) {
    if (AppConfig.useFirebase) return;
    state = state.copyWith(
      xp: state.xp + xpEarned,
      coins: state.coins + coinsEarned,
      streak: state.streak + 1,
    );
    final prefs = ref.read(sharedPreferencesProvider);
    prefs
      ..setInt(_keyXp, state.xp)
      ..setInt(_keyCoins, state.coins)
      ..setInt(_keyStreak, state.streak);
  }

  /// Removes totals an earlier build left on the device.
  ///
  /// Switching a device to Firebase mode does not erase what demo mode
  /// wrote, and those stale numbers are what a parent finds when they look
  /// in local storage and compare it with the dashboard. Called once at
  /// startup, from [main].
  static Future<void> dropBackendOwnedCopy(SharedPreferences prefs) async {
    if (!AppConfig.useFirebase) return;
    await prefs.remove(_keyXp);
    await prefs.remove(_keyCoins);
    await prefs.remove(_keyStreak);
  }
}

final demoProgressProvider = NotifierProvider<DemoProgress, Progress>(
  DemoProgress.new,
);
