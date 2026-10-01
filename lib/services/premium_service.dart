import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enum representing available Premium subscription and license tiers
enum PremiumPlanType {
  monthly,
  yearly,
  lifetime,
}

/// Metadata model describing a Premium plan for display and billing
class PremiumPlanInfo {
  final PremiumPlanType type;
  final String productId;
  final String title;
  final String subtitle;
  final String? badge;
  final bool isBestValue;

  const PremiumPlanInfo({
    required this.type,
    required this.productId,
    required this.title,
    required this.subtitle,
    this.badge,
    this.isBestValue = false,
  });
}

/// Service managing Premium entitlement, multi-tier Google Play Billing,
/// product querying, and purchase persistence across app restarts.
///
/// Features:
/// - Single source of truth for Premium entitlement via [isPremiumNotifier].
/// - Multi-plan Google Play Billing: Monthly, Yearly (Best Value), and Lifetime.
/// - Backward-compatible with legacy [premiumProductId] ('remove_ads_premium').
/// - Real-time purchase stream listening via [InAppPurchase.instance.purchaseStream].
/// - Full offline entitlement caching via [SharedPreferences].
/// - 100% ad suppression across Banner, Interstitial, and Rewarded ads.
/// - Unlocks all advanced PDF & OCR tools immediately.
/// - Safe error handling: never crashes in unit tests, web, or when offline.
class PremiumService {
  PremiumService._internal();
  static final PremiumService instance = PremiumService._internal();
  factory PremiumService() => instance;

  // ===========================================================================
  // PRODUCT IDS & CONFIGURATION
  // ===========================================================================

  /// Google Play Console Product IDs for Subscriptions and In-App Products.
  /// Configure these exact IDs under Monetize > Subscriptions / In-app products
  /// in Google Play Console.
  static const String premiumMonthlyId = 'premium_monthly';
  static const String premiumYearlyId = 'premium_yearly';
  static const String premiumLifetimeId = 'premium_lifetime';
  static const String legacyRemoveAdsId = 'remove_ads_premium';

  /// Legacy alias for backward compatibility with existing code
  static const String premiumProductId = legacyRemoveAdsId;

  /// Complete set of product identifiers queried from Google Play Billing
  static const Set<String> allProductIds = {
    premiumMonthlyId,
    premiumYearlyId,
    premiumLifetimeId,
    legacyRemoveAdsId,
  };

  /// UI-ready configurations for each supported plan
  static const List<PremiumPlanInfo> availablePlans = [
    PremiumPlanInfo(
      type: PremiumPlanType.yearly,
      productId: premiumYearlyId,
      title: 'Yearly Plan',
      subtitle: 'Billed annually • 12 months for the price of 6',
      badge: 'BEST VALUE • SAVE 50%',
      isBestValue: true,
    ),
    PremiumPlanInfo(
      type: PremiumPlanType.monthly,
      productId: premiumMonthlyId,
      title: 'Monthly Plan',
      subtitle: 'Billed monthly • Cancel anytime in Google Play',
      badge: 'FLEXIBLE',
    ),
    PremiumPlanInfo(
      type: PremiumPlanType.lifetime,
      productId: premiumLifetimeId,
      title: 'Lifetime License',
      subtitle: 'One-time payment • Keep forever on all your devices',
      badge: 'ONE-TIME',
    ),
  ];

  // Storage keys
  static const String _keyIsPremium = 'is_premium_active';
  static const String _keyActivePlanId = 'premium_active_plan_id';
  static const String _keyPurchaseDate = 'premium_purchased_at';

  // ===========================================================================
  // STATE & NOTIFIERS
  // ===========================================================================

  /// Main entitlement state: whether the user currently has an active Premium pass
  final ValueNotifier<bool> isPremiumNotifier = ValueNotifier<bool>(false);
  bool get isPremium => isPremiumNotifier.value;

  /// Whether the Google Play Store billing service is available on this device
  final ValueNotifier<bool> isStoreAvailableNotifier =
      ValueNotifier<bool>(false);
  bool get isStoreAvailable => isStoreAvailableNotifier.value;

  /// Map of product ID to Google Play ProductDetails fetched from store
  final ValueNotifier<Map<String, ProductDetails>> productsNotifier =
      ValueNotifier<Map<String, ProductDetails>>({});
  Map<String, ProductDetails> get products => productsNotifier.value;

  /// Backward-compatible product details getter for legacy references
  final ValueNotifier<ProductDetails?> productDetailsNotifier =
      ValueNotifier<ProductDetails?>(null);
  ProductDetails? get removeAdsProduct => productDetailsNotifier.value;
  bool get isPlayStoreProductConfigured =>
      productsNotifier.value.isNotEmpty || productDetailsNotifier.value != null;

  /// Loading states
  final ValueNotifier<bool> isLoadingProductsNotifier =
      ValueNotifier<bool>(false);
  bool get isLoadingProducts => isLoadingProductsNotifier.value;

  final ValueNotifier<bool> isPurchasingNotifier = ValueNotifier<bool>(false);
  bool get isPurchasing => isPurchasingNotifier.value;

  /// Event notifiers for user feedback
  final ValueNotifier<String?> purchaseErrorNotifier =
      ValueNotifier<String?>(null);
  final ValueNotifier<String?> purchaseSuccessNotifier =
      ValueNotifier<String?>(null);

  /// Active plan information
  final ValueNotifier<String?> activePlanIdNotifier =
      ValueNotifier<String?>(null);
  String? get activePlanId => activePlanIdNotifier.value;

  final ValueNotifier<DateTime?> purchaseDateNotifier =
      ValueNotifier<DateTime?>(null);
  DateTime? get purchaseDate => purchaseDateNotifier.value;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool get _isPlatformSupported {
    if (kIsWeb) return false;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  // ===========================================================================
  // INITIALIZATION & CACHE
  // ===========================================================================

  /// Initializes the Premium service, restores cached entitlement, and sets up
  /// Google Play purchase stream listeners.
  Future<void> init() async {
    if (_isInitialized) return;

    // 1. Load cached entitlement and active plan from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      isPremiumNotifier.value = prefs.getBool(_keyIsPremium) ?? false;
      activePlanIdNotifier.value = prefs.getString(_keyActivePlanId);

      final dateStr = prefs.getString(_keyPurchaseDate);
      if (dateStr != null && dateStr.isNotEmpty) {
        purchaseDateNotifier.value = DateTime.tryParse(dateStr);
      }

      debugPrint(
        '[PremiumService] Loaded cached status: premium=${isPremiumNotifier.value}, '
        'plan=${activePlanIdNotifier.value}',
      );
    } catch (e) {
      debugPrint('[PremiumService] Error reading cached status: $e');
    }

    if (!_isPlatformSupported) {
      debugPrint(
        '[PremiumService] Platform unsupported or FLUTTER_TEST. Billing disabled.',
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
          purchaseErrorNotifier.value = 'Billing connection error: $error';
        },
      );

      // 3. Verify store availability & load product details
      final available = await InAppPurchase.instance.isAvailable();
      isStoreAvailableNotifier.value = available;

      if (available) {
        await loadProducts();
      } else {
        debugPrint(
          '[PremiumService] InAppPurchase store is currently unavailable on this device.',
        );
      }
    } catch (e) {
      debugPrint('[PremiumService] Billing initialization exception: $e');
    }

    _isInitialized = true;
  }

  /// Queries Google Play Store for all configured product IDs.
  Future<void> loadProducts() async {
    if (!_isPlatformSupported) return;

    isLoadingProductsNotifier.value = true;
    try {
      final ProductDetailsResponse response =
          await InAppPurchase.instance.queryProductDetails(allProductIds);

      if (response.error != null) {
        debugPrint(
          '[PremiumService] queryProductDetails error: ${response.error}',
        );
        isLoadingProductsNotifier.value = false;
        return;
      }

      final Map<String, ProductDetails> map = {};
      for (final product in response.productDetails) {
        map[product.id] = product;
        debugPrint(
          '[PremiumService] Loaded store product: ${product.id} - ${product.price}',
        );
      }

      productsNotifier.value = map;

      // Backward compatibility pointer
      if (map.containsKey(legacyRemoveAdsId)) {
        productDetailsNotifier.value = map[legacyRemoveAdsId];
      } else if (map.isNotEmpty) {
        productDetailsNotifier.value = map.values.first;
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint(
          '[PremiumService] Products pending in Play Console: ${response.notFoundIDs.join(', ')}',
        );
      }
    } catch (e) {
      debugPrint('[PremiumService] Exception querying products: $e');
    } finally {
      isLoadingProductsNotifier.value = false;
    }
  }

  /// Helper to get product details for a given ID
  ProductDetails? getProduct(String productId) {
    return productsNotifier.value[productId];
  }

  /// Formatted price helper returning localized price or fallback
  String getPrice(String productId, {String fallback = '—'}) {
    final product = productsNotifier.value[productId];
    if (product != null && product.price.isNotEmpty) {
      return product.price;
    }
    return fallback;
  }

  // ===========================================================================
  // PURCHASE FLOW
  // ===========================================================================

  /// Initiates Google Play purchase flow for a specific product ID.
  Future<void> buyPlan(BuildContext context, String productId) async {
    if (isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Premium is already active on this device!'),
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

    // Refresh store products if not yet loaded
    if (!productsNotifier.value.containsKey(productId) && isStoreAvailable) {
      await loadProducts();
    }

    final product = productsNotifier.value[productId];
    if (product == null) {
      if (!context.mounted) return;
      _showPendingConfigurationDialog(context, productId);
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
      debugPrint('[PremiumService] Exception during purchase: $e');
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

  /// Backward-compatible buy method for existing Remove Ads actions
  Future<void> buyRemoveAds(BuildContext context) async {
    // Attempt preferred legacy ID or fall back to yearly
    if (productsNotifier.value.containsKey(legacyRemoveAdsId)) {
      await buyPlan(context, legacyRemoveAdsId);
    } else {
      await buyPlan(context, premiumYearlyId);
    }
  }

  /// Restores previous purchases made by the user from Google Play.
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
      isPurchasingNotifier.value = true;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Connecting to Google Play to restore purchases...'),
              ],
            ),
          ),
        );
      }

      await InAppPurchase.instance.restorePurchases();

      // Reset loading after brief grace period for purchaseStream updates
      Future.delayed(const Duration(seconds: 3), () {
        isPurchasingNotifier.value = false;
      });
    } catch (e) {
      isPurchasingNotifier.value = false;
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

  // ===========================================================================
  // PURCHASE STREAM LISTENER & ACKNOWLEDGEMENT
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
          purchaseErrorNotifier.value =
              purchaseDetails.error?.message ?? 'Purchase was not completed.';
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          debugPrint('[PremiumService] Purchase canceled by user.');
          purchaseErrorNotifier.value = 'Purchase cancelled.';
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          // Check if product is recognized
          if (allProductIds.contains(purchaseDetails.productID)) {
            await _setPremium(true, planId: purchaseDetails.productID);
            purchaseSuccessNotifier.value =
                purchaseDetails.status == PurchaseStatus.restored
                    ? 'Your purchases have been successfully restored!'
                    : 'Thank you! Premium has been successfully activated.';
          }
        }

        // Acknowledge receipt to Google Play
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

  Future<void> _setPremium(bool value, {String? planId}) async {
    isPremiumNotifier.value = value;
    activePlanIdNotifier.value = value ? planId : null;
    final now = value ? DateTime.now() : null;
    purchaseDateNotifier.value = now;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsPremium, value);
      if (value && planId != null) {
        await prefs.setString(_keyActivePlanId, planId);
        await prefs.setString(_keyPurchaseDate, now!.toIso8601String());
      } else if (!value) {
        await prefs.remove(_keyActivePlanId);
        await prefs.remove(_keyPurchaseDate);
      }
      debugPrint(
        '[PremiumService] Saved premium status: $value, plan: $planId',
      );
    } catch (e) {
      debugPrint('[PremiumService] Error saving premium status: $e');
    }
  }

  // ===========================================================================
  // TESTING & DEBUG HELPERS
  // ===========================================================================

  /// Toggles premium state locally for development and testing.
  /// Persists in SharedPreferences so app restarts retain the test state.
  Future<void> setPremiumForTesting(
    bool value, {
    String planId = premiumYearlyId,
  }) async {
    await _setPremium(value, planId: value ? planId : null);
  }

  // ===========================================================================
  // CONFIGURATION DIALOG
  // ===========================================================================

  void _showPendingConfigurationDialog(
    BuildContext context,
    String productId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Row(
          children: [
            Icon(Icons.storefront_rounded, color: Color(0xFF7046A8)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Play Console Setup Required',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Google Play product "$productId" is not yet available in the store query.\n',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              Text(
                'To test live Google Play transactions:\n'
                '1. Go to Google Play Console > Monetize > In-app products or Subscriptions.\n'
                '2. Create product ID "$productId".\n'
                '3. Upload your app bundle to a Closed Testing track.\n'
                '4. Add your Google account under Setup > License Testing.',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: Color(0xFF5D4037),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Tip: For local testing before publishing to Play Console, you can toggle Premium from Settings > Developer Testing.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF581C87),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void dispose() {
    _purchaseSubscription?.cancel();
    isPremiumNotifier.dispose();
    isStoreAvailableNotifier.dispose();
    productsNotifier.dispose();
    productDetailsNotifier.dispose();
    isLoadingProductsNotifier.dispose();
    isPurchasingNotifier.dispose();
    purchaseErrorNotifier.dispose();
    purchaseSuccessNotifier.dispose();
    activePlanIdNotifier.dispose();
    purchaseDateNotifier.dispose();
  }
}
