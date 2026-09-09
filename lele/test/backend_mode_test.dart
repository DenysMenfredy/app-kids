import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/config/app_config.dart';
import 'package:lele/features/auth/data/auth_repository.dart';
import 'package:lele/features/lesson/data/lesson_sync_service.dart';
import 'package:lele/features/paywall/application/entitlement_provider.dart';
import 'package:lele/features/paywall/data/subscription_service.dart';
import 'package:lele/features/session/data/profile_sync_service.dart';

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
    await expectLater(lessonSync.lessonStarted('lesson_008'), completes);
    await expectLater(
      lessonSync.lessonCompleted('lesson_008', score: 100),
      completes,
    );
  });

  test('checkout reports being unavailable instead of half-working',
      () async {
    final service = makeContainer().read(subscriptionServiceProvider);
    expect(service, isA<UnavailableSubscriptionService>());
    await expectLater(
      service.createCheckoutSession('founder_annual'),
      throwsA(isA<CheckoutFailure>()),
    );
  });

  test('premium is inactive without a backend (fails safe)', () async {
    final container = makeContainer();
    // Hold a subscription: Riverpod auto-disposes providers nobody listens
    // to, which would tear the stream down before it emits.
    final subscription = container.listen(
      premiumActiveProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    await expectLater(
      container.read(premiumActiveProvider.future),
      completion(isFalse),
    );
    expect(container.read(isPremiumProvider), isFalse);
  });
}
