import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'premium_service.dart';

/// Service managing Google Mobile Ads (AdMob) integration.
///
/// Features:
/// - Official Google sample test Ad IDs for safe development and review.
/// - Full 3-format AdMob support: Banner Ads, Interstitial Ads, and Rewarded Ads.
/// - Switchable flag `useTestAds` and explicit production ad unit placeholders.
/// - Frequency-capped Interstitials (minimum 60-second cooldown).
/// - Non-intrusive Rewarded Ads for optional perks (e.g. Ultra HD 300 DPI image export).
/// - 100% ad suppression when Premium (Remove Ads) is active via `PremiumService`.
/// - Safe error handling: never crashes in tests, web, or when network is offline.
/// - Core document viewing, reading, searching, and tools remain 100% free without ads.
class AdMobService {
  AdMobService._internal();
  static final AdMobService instance = AdMobService._internal();

  // ===========================================================================
  // CONFIGURATION & AD UNIT IDS
  // ===========================================================================

  /// Real Android AdMob Application ID
  static const String androidAppId =
      'ca-app-pub-1954229527229994~1075422211';

  /// When `true`, official Google sample test ad units are used.
  /// Automatically defaults to `true` during debug/testing to protect the AdMob account
  /// from policy violations and accidental self-clicks.
  /// In release builds (`flutter build appbundle --release`), defaults to `false` to serve real ads.
  static bool useTestAds =
      kDebugMode || Platform.environment.containsKey('FLUTTER_TEST');

  // --- OFFICIAL GOOGLE SAMPLE TEST AD UNIT IDS (FOR DEV / TESTING / CI) ---
  // https://developers.google.com/admob/android/test-ads
  // Banner
  static const String testAndroidBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String testIosBannerAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';

  // Interstitial
  static const String testAndroidInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testIosInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';

  // Rewarded
  static const String testAndroidRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String testIosRewardedAdUnitId =
      'ca-app-pub-3940256099942544/1712485313';

  // --- REAL PRODUCTION ADMOB AD UNIT IDS ---
  // Registered for All Documents Reader on Google AdMob Console
  static const String prodAndroidBannerAdUnitId =
      'ca-app-pub-1954229527229994/6297538316';
  static const String prodIosBannerAdUnitId =
      'ca-app-pub-1954229527229994/6297538316';

  static const String prodAndroidInterstitialAdUnitId =
      'ca-app-pub-1954229527229994/9853639941';
  static const String prodIosInterstitialAdUnitId =
      'ca-app-pub-1954229527229994/9853639941';

  static const String prodAndroidRewardedAdUnitId =
      'ca-app-pub-1954229527229994/8241622488';
  static const String prodIosRewardedAdUnitId =
      'ca-app-pub-1954229527229994/8241622488';

  /// Returns the appropriate Banner Ad Unit ID for the current platform and mode.
  String get bannerAdUnitId {
    if (useTestAds) {
      return Platform.isAndroid
          ? testAndroidBannerAdUnitId
          : testIosBannerAdUnitId;
    }
    return Platform.isAndroid
        ? prodAndroidBannerAdUnitId
        : prodIosBannerAdUnitId;
  }

  /// Returns the appropriate Interstitial Ad Unit ID for the current platform and mode.
  String get interstitialAdUnitId {
    if (useTestAds) {
      return Platform.isAndroid
          ? testAndroidInterstitialAdUnitId
          : testIosInterstitialAdUnitId;
    }
    return Platform.isAndroid
        ? prodAndroidInterstitialAdUnitId
        : prodIosInterstitialAdUnitId;
  }

  /// Returns the appropriate Rewarded Ad Unit ID for the current platform and mode.
  String get rewardedAdUnitId {
    if (useTestAds) {
      return Platform.isAndroid
          ? testAndroidRewardedAdUnitId
          : testIosRewardedAdUnitId;
    }
    return Platform.isAndroid
        ? prodAndroidRewardedAdUnitId
        : prodIosRewardedAdUnitId;
  }

  // ===========================================================================
  // STATE & INITIALIZATION
  // ===========================================================================

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  RewardedAd? _rewardedAd;
  bool _isLoadingRewarded = false;
  bool get isRewardedAdLoaded => _rewardedAd != null;
  bool get isAdLoaded => isRewardedAdLoaded; // Backward compatibility

  InterstitialAd? _interstitialAd;
  bool _isLoadingInterstitial = false;
  bool get isInterstitialAdLoaded => _interstitialAd != null;

  /// Cooldown between interstitial ad displays to prevent user disruption.
  static const Duration interstitialCooldown = Duration(seconds: 60);
  DateTime? _lastInterstitialTime;

  /// Tracks rewarded status within the current app session for unlocked perks.
  final Set<String> _sessionUnlockedPerks = <String>{};

  /// A perk is considered unlocked if either:
  /// 1. The user has purchased Premium (Remove Ads), which unlocks all features ad-free.
  /// 2. The user has watched an ad for this session perk.
  bool isPerkUnlocked(String perkId) =>
      PremiumService.instance.isPremium ||
      _sessionUnlockedPerks.contains(perkId);

  void unlockPerk(String perkId) {
    _sessionUnlockedPerks.add(perkId);
  }

  /// Whether the environment supports native AdMob plugins.
  bool get _isPlatformSupported {
    if (kIsWeb) return false;
    // Avoid running native calls during widget/unit tests
    if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Initializes the Google Mobile Ads SDK safely.
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (!_isPlatformSupported) {
      debugPrint(
        '[AdMobService] Platform unsupported or running in test mode. Ads disabled.',
      );
      _isInitialized = true;
      return;
    }

    try {
      final status = await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('[AdMobService] MobileAds initialized successfully: $status');

      // Preload ads in background if not premium
      if (!PremiumService.instance.isPremium) {
        loadRewardedAd();
        loadInterstitialAd();
      }
    } catch (e) {
      debugPrint(
        '[AdMobService] MobileAds initialization failed gracefully: $e',
      );
      _isInitialized = true;
    }
  }

  // ===========================================================================
  // BANNER AD HELPER
  // ===========================================================================

  /// Creates and returns a configured BannerAd instance, or null if ads are disabled.
  BannerAd? createBannerAd({
    required VoidCallback onAdLoaded,
    required void Function(LoadAdError) onAdFailedToLoad,
    AdSize size = AdSize.banner,
  }) {
    if (PremiumService.instance.isPremium || !_isPlatformSupported) {
      return null;
    }

    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('[AdMobService] Banner ad loaded successfully.');
          onAdLoaded();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdMobService] Banner ad failed to load: $error');
          // Note: Disposal is handled by the caller/BannerAdWidget state
          onAdFailedToLoad(error);
        },
      ),
    );
  }

  // ===========================================================================
  // INTERSTITIAL AD LOADING & PRESENTATION
  // ===========================================================================

  /// Preloads an Interstitial Ad in the background.
  Future<void> loadInterstitialAd() async {
    if (!_isPlatformSupported ||
        PremiumService.instance.isPremium ||
        _isLoadingInterstitial ||
        _interstitialAd != null) {
      return;
    }
    _isLoadingInterstitial = true;

    try {
      await InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            _interstitialAd = ad;
            _isLoadingInterstitial = false;
            debugPrint('[AdMobService] Interstitial ad loaded successfully.');
          },
          onAdFailedToLoad: (LoadAdError error) {
            debugPrint('[AdMobService] Interstitial ad failed to load: $error');
            _interstitialAd = null;
            _isLoadingInterstitial = false;
          },
        ),
      );
    } catch (e) {
      debugPrint('[AdMobService] Error while requesting interstitial ad: $e');
      _isLoadingInterstitial = false;
    }
  }

  /// Shows an Interstitial Ad at natural transition points (e.g. tool completion),
  /// respecting the 60-second cooldown frequency cap and Premium status.
  ///
  /// Returns `true` if an ad was displayed, `false` if skipped or suppressed.
  Future<bool> showInterstitialAd({
    BuildContext? context,
    String triggerReason = 'tool_action',
  }) async {
    // 1. Premium users are never shown ads
    if (PremiumService.instance.isPremium) {
      debugPrint(
        '[AdMobService] User is Premium. Interstitial ad suppressed ($triggerReason).',
      );
      return false;
    }

    // 2. Unsupported platform or test mode
    if (!_isPlatformSupported) {
      debugPrint(
        '[AdMobService] Platform unsupported or FLUTTER_TEST. Interstitial bypassed ($triggerReason).',
      );
      return false;
    }

    // 3. Check frequency cooldown
    if (_lastInterstitialTime != null) {
      final elapsed = DateTime.now().difference(_lastInterstitialTime!);
      if (elapsed < interstitialCooldown) {
        final remaining = interstitialCooldown.inSeconds - elapsed.inSeconds;
        debugPrint(
          '[AdMobService] Interstitial cooldown active ($remaining s remaining). Suppressed ($triggerReason).',
        );
        return false;
      }
    }

    // 4. If ad is actively loading, give it up to 1000ms to finish
    if (_interstitialAd == null && _isLoadingInterstitial) {
      debugPrint(
        '[AdMobService] Interstitial ad actively loading. Waiting briefly ($triggerReason)...',
      );
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_interstitialAd != null) break;
      }
    }

    final ad = _interstitialAd;
    if (ad == null) {
      debugPrint(
        '[AdMobService] Interstitial ad not ready. Triggering background load ($triggerReason).',
      );
      loadInterstitialAd();
      return false;
    }

    // 5. Present ad
    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        debugPrint(
          '[AdMobService] Interstitial ad displayed ($triggerReason).',
        );
        _lastInterstitialTime = DateTime.now();
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        debugPrint(
          '[AdMobService] Interstitial ad dismissed ($triggerReason).',
        );
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();

        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        debugPrint(
          '[AdMobService] Interstitial ad failed to show: $error ($triggerReason)',
        );
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    try {
      ad.show();
    } catch (e) {
      debugPrint('[AdMobService] Exception presenting interstitial ad: $e');
      ad.dispose();
      _interstitialAd = null;
      loadInterstitialAd();
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future;
  }

  // ===========================================================================
  // REWARDED AD LOADING & PRESENTATION
  // ===========================================================================

  /// Preloads a Rewarded Ad in the background.
  Future<void> loadRewardedAd() async {
    if (!_isPlatformSupported || _isLoadingRewarded || _rewardedAd != null) {
      return;
    }
    _isLoadingRewarded = true;

    try {
      await RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            _rewardedAd = ad;
            _isLoadingRewarded = false;
            debugPrint('[AdMobService] Rewarded ad loaded successfully.');
          },
          onAdFailedToLoad: (LoadAdError error) {
            debugPrint('[AdMobService] Rewarded ad failed to load: $error');
            _rewardedAd = null;
            _isLoadingRewarded = false;
          },
        ),
      );
    } catch (e) {
      debugPrint('[AdMobService] Error while requesting rewarded ad: $e');
      _isLoadingRewarded = false;
    }
  }

  /// Shows the Rewarded Ad if available.
  ///
  Future<bool> showRewardedAd({
    required BuildContext context,
    required String rewardReason,
  }) async {
    // Premium users bypass all ads and automatically receive perks
    if (PremiumService.instance.isPremium) {
      debugPrint('[AdMobService] User is Premium. Rewarded ad bypassed and perk granted ($rewardReason).');
      return true;
    }

    // If running in widget/unit tests or unsupported environment, allow test execution
    if (!_isPlatformSupported) {
      debugPrint('[AdMobService] Platform unsupported or FLUTTER_TEST. Bypassing native ad in test mode.');
      return true;
    }

    // If ad is preloaded and ready, show it directly
    if (_rewardedAd != null) {
      final completer = Completer<bool>();
      _presentLoadedAd(completer, rewardReason);
      return completer.future;
    }

    // Ad is not preloaded yet: show a loading indicator while requesting test ad
    debugPrint('[AdMobService] Ad not preloaded. Fetching Google test ad on demand...');
    BuildContext? loadingDialogContext;
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          loadingDialogContext = ctx;
          return PopScope(
            canPop: false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: const Row(
                children: [
                  CircularProgressIndicator(color: Color(0xFF7046A8)),
                  SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      'Loading Google Test Ad...',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    final completer = Completer<bool>();

    try {
      await RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            debugPrint('[AdMobService] On-demand ad loaded successfully.');
            if (loadingDialogContext != null && loadingDialogContext!.mounted) {
              Navigator.of(loadingDialogContext!).pop();
            }
            _rewardedAd = ad;
            _presentLoadedAd(completer, rewardReason);
          },
          onAdFailedToLoad: (LoadAdError error) {
            debugPrint('[AdMobService] On-demand ad failed to load: $error');
            if (loadingDialogContext != null && loadingDialogContext!.mounted) {
              Navigator.of(loadingDialogContext!).pop();
            }
            _rewardedAd = null;
            if (!completer.isCompleted) {
              completer.complete(false); // Do not silently grant reward!
            }
          },
        ),
      );
    } catch (e) {
      debugPrint('[AdMobService] Exception loading ad on demand: $e');
      if (loadingDialogContext != null && loadingDialogContext!.mounted) {
        Navigator.of(loadingDialogContext!).pop();
      }
      return false; // Do not silently grant reward!
    }

    return completer.future;
  }

  void _presentLoadedAd(Completer<bool> completer, String rewardReason) {
    final ad = _rewardedAd;
    if (ad == null) {
      if (!completer.isCompleted) completer.complete(false);
      return;
    }

    bool earnedReward = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) {
        debugPrint('[AdMobService] Rewarded ad showing full screen.');
      },
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        debugPrint('[AdMobService] Rewarded ad dismissed. earnedReward: $earnedReward');
        ad.dispose();
        _rewardedAd = null;
        // Preload next ad in background
        loadRewardedAd();
        if (!completer.isCompleted) {
          completer.complete(earnedReward);
        }
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        debugPrint('[AdMobService] Failed to show rewarded ad: $error');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        if (!completer.isCompleted) {
          completer.complete(false); // Do not silently grant reward!
        }
      },
    );

    ad.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        debugPrint(
          '[AdMobService] onUserEarnedReward received for $rewardReason: '
          '${reward.amount} ${reward.type}',
        );
        earnedReward = true;
      },
    );
  }

  // ===========================================================================
  // USER PROMPT DIALOG
  // ===========================================================================

  /// Displays an elegant, transparent user prompt explaining that watching a short
  /// sponsored ad will unlock a specific premium capability for the session.
  ///
  /// Returns `true` if unlocked, or `false` if cancelled or failed.
  Future<bool> showRewardedAdPrompt(
    BuildContext context, {
    required String title,
    String description = 'Watch a short ad to unlock this advanced option',
    required String perkKey,
    String actionButtonLabel = 'Watch Ad',
    String cancelButtonLabel = 'Not Now',
    String? unlockNotice,
    String? perkUnlockedMessage,
  }) async {
    // If already unlocked for this session, return true immediately
    if (isPerkUnlocked(perkKey)) {
      return true;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: isDark ? const Color(0xFF261D33) : Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E5FC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  color: Color(0xFF7046A8),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF2D2435),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[200] : const Color(0xFF2D2435),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1729)
                      : const Color(0xFFF7F4FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF7046A8).withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.movie_outlined,
                      color: Color(0xFF7046A8),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        unlockNotice ??
                            'Watch a short ad to unlock this advanced option. Standard options remain 100% free without ads.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : const Color(0xFF6C6374),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                cancelButtonLabel,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7046A8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
              label: Text(
                actionButtonLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );

    if (result != true) {
      return false; // User cancelled
    }

    if (!context.mounted) return false;

    // Show rewarded ad
    final rewarded = await showRewardedAd(
      context: context,
      rewardReason: perkKey,
    );

    if (rewarded) {
      unlockPerk(perkKey);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(perkUnlockedMessage ?? '$title Unlocked!'),
              ],
            ),
          ),
        );
      }
      return true;
    } else {
      // Ad failed or closed early - do NOT grant reward
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFC62828),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ad was not completed or failed to load. Continuing with free standard option.',
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return false;
    }
  }
}
