import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../data/subscription_service.dart';
import '../domain/checkout_failure.dart';

/// Buying a subscription, end to end.
///
/// Creating the session and opening it are one use case, not two: a session
/// the app never opens is a half-finished purchase, and splitting them left
/// the paywall widget holding a Stripe URL and a `url_launcher` import.
/// Everything that decides *what* may be bought stays in the backend
/// (spec §8, §16) — the client only ever handles the hosted URL.
class CheckoutController {
  const CheckoutController(this._ref);

  final Ref _ref;

  /// False in demo mode, where there is no payments backend to talk to.
  bool get paymentsEnabled => AppConfig.useFirebase;

  /// Opens hosted checkout for [backendPlanId].
  ///
  /// Throws [CheckoutFailure] with a message safe to show the parent, both
  /// when the backend refuses and when the device cannot open the page.
  Future<void> start(String backendPlanId) async {
    final url = await _ref
        .read(subscriptionServiceProvider)
        .createCheckoutSession(backendPlanId);
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw const CheckoutFailure('Não foi possível abrir o pagamento.');
    }
  }
}

final checkoutControllerProvider = Provider<CheckoutController>(
  CheckoutController.new,
);
