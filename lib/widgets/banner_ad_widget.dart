import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_mob_service.dart';
import '../services/premium_service.dart';

/// A reusable widget that displays an AdMob Banner Ad safely.
///
/// Features:
/// - Automatically queries anchored adaptive banner size with fallback to standard 320x50.
/// - Automatically hides (`SizedBox.shrink()`) if Premium (Remove Ads) is active.
/// - Automatically collapses if the ad fails to load or if running on unsupported platforms / tests.
/// - Cleans up and disposes of the native ad instance on widget disposal without double-disposal.
/// - Uses `AdWidget` to render the loaded native ad inside an appropriately sized container.
class BannerAdWidget extends StatefulWidget {
  final EdgeInsetsGeometry margin;

  const BannerAdWidget({
    super.key,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Listen for Premium status changes so banner hides immediately upon purchase
    PremiumService.instance.isPremiumNotifier.addListener(_onPremiumChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!PremiumService.instance.isPremium &&
        !_isAdLoaded &&
        !_isLoading &&
        _bannerAd == null) {
      _loadBanner();
    }
  }

  void _onPremiumChanged() {
    if (PremiumService.instance.isPremium) {
      _disposeBanner();
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadBanner() async {
    if (kIsWeb || (Platform.isAndroid == false && Platform.isIOS == false)) {
      return;
    }
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    if (PremiumService.instance.isPremium) {
      return;
    }

    _isLoading = true;

    AdSize adSize = AdSize.banner;
    try {
      final width = MediaQuery.sizeOf(context).width.truncate();
      if (width > 0) {
        final adaptive =
            await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
        if (adaptive != null) {
          adSize = adaptive;
        }
      }
    } catch (_) {
      adSize = AdSize.banner;
    }

    if (!mounted || PremiumService.instance.isPremium) {
      _isLoading = false;
      return;
    }

    _bannerAd = AdMobService.instance.createBannerAd(
      size: adSize,
      onAdLoaded: () {
        if (mounted) {
          setState(() {
            _isAdLoaded = true;
            _isLoading = false;
          });
        }
      },
      onAdFailedToLoad: (error) {
        debugPrint('[BannerAdWidget] Banner failed to load: $error');
        _disposeBanner();
        if (mounted) {
          setState(() {
            _isAdLoaded = false;
            _isLoading = false;
          });
        }
      },
    );

    _bannerAd?.load();
  }

  void _disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isAdLoaded = false;
    _isLoading = false;
  }

  @override
  void dispose() {
    PremiumService.instance.isPremiumNotifier.removeListener(_onPremiumChanged);
    _disposeBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If premium or ad is not loaded, do not occupy any visual space
    if (PremiumService.instance.isPremium || !_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: widget.margin,
      alignment: Alignment.center,
      child: Container(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1729) : const Color(0xFFF9F7FD),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFF7046A8).withValues(alpha: 0.12),
            width: 0.8,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
