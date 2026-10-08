import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/config/app_config.dart';
import 'package:lele/core/storage/local_storage.dart';
import 'package:lele/features/auth/data/auth_repository.dart';
import 'package:lele/features/lesson/data/lesson_sync_service.dart';
import 'package:lele/features/paywall/application/checkout_controller.dart';
import 'package:lele/features/paywall/application/entitlement_provider.dart';
import 'package:lele/features/paywall/data/subscription_service.dart';
import 'package:lele/features/paywall/domain/checkout_failure.dart';
import 'package:lele/features/session/application/demo_progress_controller.dart';
import 'package:lele/features/session/application/progress_provider.dart';
import 'package:lele/features/session/data/profile_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// These run in local mode (USE_FIREBASE unset), which is the default for
/// tests and for development before `flutterfire configure` has run. They
/// pin the contract that no Firebase instance is touched in that mode —
/// reading one would throw, since Firebase.initializeApp never ran.
void main() {
  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('local mode is the default', () {
    expect(AppConfig.useFirebase, isFalse);
  });

  /// The totals shown on screen and the totals on the device have to be the
  /// same totals. They were not: the session persisted XP, coins and the
  /// streak in both modes, while with the backend on the dashboard read the
  /// numbers Firestore minted — 120 stored against 200 shown.
  ///
  /// In this mode the device *is* the source, so the startup cleanup that
  /// drops the backend-owned copy must leave it completely alone.
  test('what local storage holds is what the screen shows', () async {
    SharedPreferences.setMockInitialValues({
      'session.xp': 500,
      'session.coins': 99,
      'session.streak': 7,
    });
    final prefs = await SharedPreferences.getInstance();

    await DemoProgress.dropBackendOwnedCopy(prefs);

    expect(
      prefs.getInt('session.xp'),
      500,
      reason: 'demo progress is owned here',
    );
    expect(prefs.getInt('session.coins'), 99);
    expect(prefs.getInt('session.streak'), 7);

    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final shown = container.read(progressProvider);
    expect(shown.xp, prefs.getInt('session.xp'));
    expect(shown.coins, prefs.getInt('session.coins'));
    expect(shown.streak, prefs.getInt('session.streak'));
  });

  test('auth resolves to the offline fake', () {
    final repository = makeContainer().read(authRepositoryProvider);
    expect(repository, isA<FakeAuthRepository>());
    expect(repository.currentUserId, isNull);
  });

  test('sync services are no-ops that never throw', () async {
    final container = makeContainer();
    final profileSync = container.read(profileSyncServiceProvider);
    final lessonSync = container.read(lessonSyncServiceProvider);
    expect(profileSync, isA<NoopProfileSyncService>());
    expect(lessonSync, isA<NoopLessonSyncService>());

    await expectLater(profileSync.syncParentName('Camila'), completes);
    await expectLater(
      lessonSync.lessonStarted('lesson_008', 'child_1'),
      completes,
    );
    await expectLater(
      lessonSync.activityAttempt(
        'lesson_008',
        'child_1',
        'activity_008_tap',
        {'selectedLabel': 'D'},
      ),
      completes,
    );
    await expectLater(
      lessonSync.lessonCompleted('lesson_008', 'child_1'),
      completes,
    );
  });

  test('checkout reports being unavailable instead of half-working', () async {
    final container = makeContainer();
    final service = container.read(subscriptionServiceProvider);
    expect(service, isA<UnavailableSubscriptionService>());
    expect(container.read(checkoutControllerProvider).paymentsEnabled, isFalse);
    await expectLater(
      service.createCheckoutSession('founder_annual'),
      throwsA(isA<CheckoutFailure>()),
    );
    await expectLater(
      container.read(checkoutControllerProvider).start('founder_annual'),
      throwsA(isA<CheckoutFailure>()),
    );
  });

  test('premium is inactive without a backend (fails safe)', () async {
    final container = makeContainer();
    // Hold a subscription: Riverpod auto-disposes providers nobody listens
    // to, which would tear the stream down before it emits.
    final subscription = container.listen(premiumActiveProvider, (_, _) {});
    addTearDown(subscription.close);

    await expectLater(
      container.read(premiumActiveProvider.future),
      completion(isFalse),
    );
    expect(container.read(isPremiumProvider), isFalse);
  });
}
