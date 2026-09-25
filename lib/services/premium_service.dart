import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service managing Premium (Remove Ads) entitlement and Google Play Billing.
///
/// Features:
/// - Real one-time non-consumable purchase architecture (`remove_ads_premium`).
/// - Listens to `InAppPurchase.instance.purchaseStream` for live transactions.
/// - Caches entitlement state locally via `SharedPreferences`.
/// - Hides all Banner and Interstitial Ads when active.
/// - Safe error handling: never crashes in unit tests, web, or when offline.
class PremiumService {
  PremiumService._internal();
  static final PremiumService instance = PremiumService._internal();
  factory PremiumService() => instance;

  // ===========================================================================
  // CONSTANTS & PRODUCT IDS
  // ===========================================================================

  /// Official Google Play Console Product ID for the one-time Remove Ads purchase.
  /// Configure this as a "Non-consumable" / "In-app product" in Google Play Console.
  static const String premiumProductId = 'remove_ads_premium';

  static const String _keyIsPremium = 'is_premium_active';

  // ===========================================================================
  // STATE
  // ===========================================================================

  final ValueNotifier<bool> isPremiumNotifier = ValueNotifier<bool>(false);
  bool get isPremium => isPremiumNotifier.value;

  final ValueNotifier<bool> isStoreAvailableNotifier =
      ValueNotifier<bool>(false);
  bool get isStoreAvailable => isStoreAvailableNotifier.value;

  final ValueNotifier<ProductDetails?> productDetailsNotifier =
      ValueNotifier<ProductDetails?>(null);
  ProductDetails? get removeAdsProduct => productDetailsNotifier.value;
  bool get isPlayStoreProductConfigured => removeAdsProduct != null;

  final ValueNotifier<bool> isPurchasingNotifier = ValueNotifier<bool>(false);
  bool get isPurchasing => isPurchasingNotifier.value;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool get _isPlatformSupported {
    if (kIsWeb) return false;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  // ===========================================================================
  // INITIALIZATION
  // ===========================================================================

  /// Initializes the Premium service and sets up purchase listeners.
  Future<void> init() async {
    if (_isInitialized) return;

    // 1. Load cached entitlement from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      isPremiumNotifier.value = prefs.getBool(_keyIsPremium) ?? false;
      debugPrint(
        '[PremiumService] Loaded cached premium status: ${isPremiumNotifier.value}',
      );
    } catch (e) {
      debugPrint('[PremiumService] Error loading cached premium status: $e');
    }

    if (!_isPlatformSupported) {
      debugPrint(
        '[PremiumService] Platform unsupported or FLUTTER_TEST. In-App Purchase disabled.',
      );
      _isInitialized = true;
      return;
    }

    // 2. Set up purchase stream listener
    try {
      final purchaseUpdates = InAppPurchase.instance.purchaseStream;
      _purchaseSubscription = purchaseUpdates.listen(
        _handlePurchaseUpdates,
        onDone: () => _purchaseSubscription?.cancel(),
        onError: (error) {
          debugPrint('[PremiumService] Error on purchaseStream: $error');
        },
      );

      // 3. Verify store availability & load product details
      final available = await InAppPurchase.instance.isAvailable();
      isStoreAvailableNotifier.value = available;

      if (available) {
        await loadProduct();
      } else {
        debugPrint(
          '[PremiumService] InAppPurchase store is currently unavailable on this device.',
        );
      }
    } catch (e) {
      debugPrint('[PremiumService] Error during billing initialization: $e');
    }

    _isInitialized = true;
  }

  /// Queries Google Play Store for the `remove_ads_premium` product details.
  Future<void> loadProduct() async {
    if (!_isPlatformSupported) return;

    try {
      final ProductDetailsResponse response =
          await InAppPurchase.instance.queryProductDetails({premiumProductId});

      if (response.error != null) {
        debugPrint(
          '[PremiumService] queryProductDetails error: ${response.error}',
        );
        return;
      }

      if (response.productDetails.isNotEmpty) {
        final product = response.productDetails.firstWhere(
          (p) => p.id == premiumProductId,
          orElse: () => response.productDetails.first,
        );
        productDetailsNotifier.value = product;
        debugPrint(
          '[PremiumService] Loaded product: ${product.id} - ${product.title} (${product.price})',
        );
      } else {
        debugPrint(
          '[PremiumService] Product "$premiumProductId" not found in store query. '
          'Verify Play Console closed testing track setup.',
        );
      }
    } catch (e) {
      debugPrint('[PremiumService] Exception loading product: $e');
    }
  }

  // ===========================================================================
  // PURCHASE HANDLING
  // ===========================================================================

  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      debugPrint(
        '[PremiumService] Purchase update: ${purchaseDetails.productID} '
        'status: ${purchaseDetails.status}',
      );

      if (purchaseDetails.status == PurchaseStatus.pending) {
        isPurchasingNotifier.value = true;
      } else {
        isPurchasingNotifier.value = false;

        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint(
            '[PremiumService] Purchase error: ${purchaseDetails.error}',
          );
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          // Verify product ID
          if (purchaseDetails.productID == premiumProductId) {
            await _setPremium(true);
          }
        }

        // Complete purchase with Google Play to acknowledge receipt
        if (purchaseDetails.pendingCompletePurchase) {
          try {
            await InAppPurchase.instance.completePurchase(purchaseDetails);
            debugPrint(
              '[PremiumService] Acknowledged purchase: ${purchaseDetails.purchaseID}',
            );
          } catch (e) {
            debugPrint('[PremiumService] Error acknowledging purchase: $e');
          }
        }
      }
    }
  }

  Future<void> _setPremium(bool value) async {
    isPremiumNotifier.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsPremium, value);
      debugPrint('[PremiumService] Saved premium status: $value');
    } catch (e) {
      debugPrint('[PremiumService] Error saving premium status: $e');
    }
  }

  // ===========================================================================
  // USER ACTIONS
  // ===========================================================================

  /// Initiates the Google Play purchase flow for `remove_ads_premium`.
  Future<void> buyRemoveAds(BuildContext context) async {
    if (isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Premium is already active! Ads are permanently removed.'),
            ],
          ),
        ),
      );
      return;
    }

    if (!_isPlatformSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('In-App Purchases are not supported on this platform.'),
        ),
      );
      return;
    }

    // Refresh product details if not loaded
    if (removeAdsProduct == null && isStoreAvailable) {
      await loadProduct();
    }

    final product = removeAdsProduct;
    if (product == null) {
      if (!context.mounted) return;
      // Store connection or Play Console pending setup
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF7046A8)),
              SizedBox(width: 10),
              Text('Store Configuration Pending'),
            ],
          ),
          content: const Text(
            'Play Console product configuration is still required.\n\n'
            'Product ID: "remove_ads_premium"\n\n'
            'To process real Google Play transactions:\n'
            '1. Publish the app bundle to an internal or closed testing track in Google Play Console.\n'
            '2. Add the in-app product "remove_ads_premium" under Monetize > In-app products.\n'
            '3. Activate the product and test using an authorized license tester account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);

    try {
      isPurchasingNotifier.value = true;
      final success = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      if (!success) {
        isPurchasingNotifier.value = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Could not start Google Play purchase flow.'),
            ),
          );
        }
      }
    } catch (e) {
      isPurchasingNotifier.value = false;
      debugPrint('[PremiumService] Exception during buyNonConsumable: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Purchase initiation failed: $e'),
          ),
        );
      }
    }
  }

  /// Restores previous non-consumable purchases from Google Play.
  Future<void> restorePurchases(BuildContext context) async {
    if (!_isPlatformSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Restore purchases is not supported on this platform.'),
        ),
      );
      return;
    }

    try {
      await InAppPurchase.instance.restorePurchases();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Restoring previous purchases from Google Play...'),
          ),
        );
      }
    } catch (e) {
      debugPrint('[PremiumService] Error restoring purchases: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Could not restore purchases: $e'),
          ),
        );
      }
    }
  }

  /// Testing helper to toggle premium state in development and tests.
  Future<void> setPremiumForTesting(bool value) async {
    await _setPremium(value);
  }

  void dispose() {
    _purchaseSubscription?.cancel();
    isPremiumNotifier.dispose();
    isStoreAvailableNotifier.dispose();
    productDetailsNotifier.dispose();
    isPurchasingNotifier.dispose();
  }
}
