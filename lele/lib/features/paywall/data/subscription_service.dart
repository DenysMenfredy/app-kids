import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/firebase/firebase_providers.dart';

/// Thrown with a user-presentable pt-BR message when checkout can't start.
class CheckoutFailure implements Exception {
  const CheckoutFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Starts a subscription purchase. The client only ever receives a hosted
/// checkout URL — plan validation, Stripe access and entitlement activation
/// all live in the backend (spec §8, §16).
abstract interface class SubscriptionService {
  Future<Uri> createCheckoutSession(String planId);
}

/// Local mode: purchases are unavailable; callers fall back to demo flow.
class UnavailableSubscriptionService implements SubscriptionService {
  const UnavailableSubscriptionService();

  @override
  Future<Uri> createCheckoutSession(String planId) async {
    throw const CheckoutFailure(
      'Pagamentos indisponíveis no modo de demonstração.',
    );
  }
}

class CallableSubscriptionService implements SubscriptionService {
  CallableSubscriptionService(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<Uri> createCheckoutSession(String planId) async {
    try {
      final result = await _functions
          .httpsCallable('createCheckoutSession')
          .call<dynamic>({'planId': planId});
      final url = (result.data as Map)['url'] as String?;
      final uri = url == null ? null : Uri.tryParse(url);
      if (uri == null) {
        throw const CheckoutFailure(
          'Não foi possível iniciar o pagamento. Tente novamente.',
        );
      }
      return uri;
    } on FirebaseFunctionsException catch (e) {
      throw CheckoutFailure(
        e.message ?? 'Não foi possível iniciar o pagamento. Tente novamente.',
      );
    }
  }
}

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  if (AppConfig.useFirebase) {
    return CallableSubscriptionService(ref.watch(functionsProvider));
  }
  return const UnavailableSubscriptionService();
});
