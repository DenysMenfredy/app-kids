import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

// Compile-time capability spike only. It does not initiate or verify a purchase.
void main() {
  final product = ProductDetails(
    id: 'test_only_not_a_store_product',
    title: 'Synthetic',
    description: 'Test fixture',
    price: r'R$ 0,01',
    rawPrice: 0.01,
    currencyCode: 'BRL',
  );

  test('Google purchase params carry opaque account ID and selected offer', () {
    final params = GooglePlayPurchaseParam(
      productDetails: product,
      applicationUserName: 'opaque_backend_generated_account_id',
      offerToken: 'synthetic-offer',
    );
    expect(params.applicationUserName, 'opaque_backend_generated_account_id');
    expect(params.offerToken, 'synthetic-offer');
    expect(params.changeSubscriptionParam, isNull);
  });

  test('StoreKit2 accepts an opaque UUID through applicationUserName', () {
    final params = Sk2PurchaseParam(
      productDetails: product,
      applicationUserName: '00000000-0000-4000-8000-000000000001',
    );
    expect(params.applicationUserName, '00000000-0000-4000-8000-000000000001');
    expect(params.introductoryOfferEligibilityCompactJWS, isNull);
  });

  test(
    'StoreKit2 exposes evidence, account token and transaction ID, not trust',
    () {
      final details = SK2PurchaseDetails(
        productID: product.id,
        purchaseID: 'test-transaction',
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: 'untrusted-jws-test-fixture',
          source: 'app_store',
        ),
        transactionDate: '0',
        status: PurchaseStatus.purchased,
        appAccountToken: '00000000-0000-4000-8000-000000000001',
      );
      expect(details.purchaseID, 'test-transaction');
      expect(
        details.verificationData.serverVerificationData,
        'untrusted-jws-test-fixture',
      );
      expect(details.pendingCompletePurchase, isTrue);
    },
  );

  test(
    'new app cannot reintroduce external checkout or fixed founder prices',
    () {
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      for (final file in files) {
        expect(
          file.readAsStringSync(),
          isNot(
            matches(
              RegExp(
                'createCheckoutSession|createCustomerPortal|ENABLE_WEB_CHECKOUT|founderPlans|founder_monthly',
              ),
            ),
          ),
          reason: file.path,
        );
      }
    },
  );
}
