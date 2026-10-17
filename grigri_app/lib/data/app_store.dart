import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../log.dart';
import '../model/premium.dart';

/// Premium on iOS (specs/premium.md, App Store guideline 3.1.1): sold
/// through the App Store's in-app purchase, as auto-renewable
/// subscriptions in one group, "Grigri Premium". The app buys through
/// StoreKit 2 with my appAccountToken, sends the signed transaction to the
/// API, then finishes it. Behind this interface so tests don't need
/// StoreKit ([InAppPurchaseAppStore] is the real one).
abstract class AppStore {
  /// Purchases as StoreKit reports them: bought, restored, renewed while
  /// the app runs, and ones left unfinished last time (at launch).
  Stream<List<StorePurchase>> get purchases;

  /// The products with the App Store's localized prices; empty when the
  /// App Store can't be reached or doesn't sell them (yet).
  Future<Map<PremiumPlan, StoreProduct>> products();

  /// Starts buying [product] for the account [accountToken] (a UUID); the
  /// outcome comes through [purchases]. False when it didn't start.
  Future<bool> buy(StoreProduct product, {required String accountToken});

  /// Asks the App Store for my current subscriptions; completes once
  /// they've come through [purchases].
  Future<void> restore();

  /// Finishes a purchase once the API has it (or it can never use it).
  Future<void> complete(StorePurchase purchase);
}

/// The App Store's product ids, one per plan.
const appStoreProductIds = {
  PremiumPlan.monthly: 'com.nu01.grigri.premium.monthly',
  PremiumPlan.yearly: 'com.nu01.grigri.premium.yearly',
};

/// Where an App Store subscription is managed or cancelled.
final appStoreSubscriptionsUrl = Uri.parse(
  'https://apps.apple.com/account/subscriptions',
);

/// Grigri's privacy policy, linked from the subscription's terms.
final privacyPolicyUrl = Uri.parse('https://grigri.nu01.com/privacy.html');

/// Apple's standard licensed application end user license agreement: the
/// subscription's terms of use.
final appleEulaUrl = Uri.parse(
  'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
);

/// A subscription as the App Store sells it here.
class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.plan,
    required this.price,
  });

  final String id;
  final PremiumPlan plan;

  /// The App Store's price, localized for my storefront: "$19.99".
  final String price;
}

enum StorePurchaseStatus { pending, purchased, restored, canceled, error }

/// A purchase StoreKit reported.
class StorePurchase {
  const StorePurchase({
    required this.productId,
    required this.status,
    this.signedTransaction = '',
    this.needsCompleting = false,
    this.handle,
  });

  final String productId;
  final StorePurchaseStatus status;

  /// StoreKit 2's signed transaction (its JWS), for the API.
  final String signedTransaction;

  /// Still to be finished (`completePurchase`).
  final bool needsCompleting;

  /// The plugin's own purchase, to finish it.
  final Object? handle;
}

/// The App Store through Flutter's `in_app_purchase` plugin (StoreKit 2,
/// its default on iOS 15 and later).
class InAppPurchaseAppStore implements AppStore {
  InAppPurchaseAppStore([InAppPurchase? iap])
    : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;
  final _details = <String, ProductDetails>{};

  @override
  Stream<List<StorePurchase>> get purchases =>
      _iap.purchaseStream.map((list) => [for (final p in list) _from(p)]);

  static StorePurchase _from(PurchaseDetails p) => StorePurchase(
    productId: p.productID,
    status: switch (p.status) {
      PurchaseStatus.pending => StorePurchaseStatus.pending,
      PurchaseStatus.purchased => StorePurchaseStatus.purchased,
      PurchaseStatus.restored => StorePurchaseStatus.restored,
      PurchaseStatus.canceled => StorePurchaseStatus.canceled,
      PurchaseStatus.error => StorePurchaseStatus.error,
    },
    // On iOS with StoreKit 2, the transaction's jwsRepresentation.
    signedTransaction: p.verificationData.serverVerificationData,
    needsCompleting: p.pendingCompletePurchase,
    handle: p,
  );

  @override
  Future<Map<PremiumPlan, StoreProduct>> products() async {
    try {
      if (!await _iap.isAvailable()) return {};
      final answer = await _iap.queryProductDetails(
        appStoreProductIds.values.toSet(),
      );
      if (answer.error != null) {
        log.warn('premium', 'App Store products: ${answer.error!.message}');
      }
      final found = <PremiumPlan, StoreProduct>{};
      for (final d in answer.productDetails) {
        final plan = appStoreProductIds.entries
            .where((e) => e.value == d.id)
            .firstOrNull
            ?.key;
        if (plan == null) continue;
        _details[d.id] = d;
        found[plan] = StoreProduct(id: d.id, plan: plan, price: d.price);
      }
      return found;
    } on Object catch (e) {
      log.warn('premium', 'App Store products failed: $e');
      return {};
    }
  }

  @override
  Future<bool> buy(StoreProduct product, {required String accountToken}) async {
    final details = _details[product.id];
    if (details == null) return false;
    // An auto-renewable subscription is bought as a non-consumable;
    // applicationUserName becomes StoreKit 2's appAccountToken.
    return _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: details,
        applicationUserName: accountToken,
      ),
    );
  }

  @override
  Future<void> restore() async {
    await _iap.restorePurchases();
    // The restored purchases reach [purchases] just after: give them a
    // moment, so "nothing to restore" isn't said too soon.
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> complete(StorePurchase purchase) async {
    final p = purchase.handle;
    if (p is PurchaseDetails && p.pendingCompletePurchase) {
      await _iap.completePurchase(p);
    }
  }
}
