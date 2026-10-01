import 'package:all_documents_reader/core/theme/app_theme.dart';
import 'package:all_documents_reader/services/premium_service.dart';
import 'package:flutter/material.dart';

/// Full-featured, production-ready Premium upgrade screen matching the app's
/// modern purple design identity.
class PremiumView extends StatefulWidget {
  final String? highlightBenefitTitle;

  const PremiumView({
    super.key,
    this.highlightBenefitTitle,
  });

  @override
  State<PremiumView> createState() => _PremiumViewState();
}

class _PremiumViewState extends State<PremiumView> {
  final PremiumService _premiumService = PremiumService.instance;
  String _selectedProductId = PremiumService.premiumYearlyId;

  @override
  void initState() {
    super.initState();
    _premiumService.purchaseErrorNotifier.addListener(_onPurchaseError);
    _premiumService.purchaseSuccessNotifier.addListener(_onPurchaseSuccess);

    // Refresh products on open if store is connected
    if (_premiumService.isStoreAvailable) {
      _premiumService.loadProducts();
    }
  }

  @override
  void dispose() {
    _premiumService.purchaseErrorNotifier.removeListener(_onPurchaseError);
    _premiumService.purchaseSuccessNotifier.removeListener(_onPurchaseSuccess);
    super.dispose();
  }

  void _onPurchaseError() {
    final error = _premiumService.purchaseErrorNotifier.value;
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFC62828),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(error, style: const TextStyle(fontSize: 13))),
            ],
          ),
        ),
      );
      _premiumService.purchaseErrorNotifier.value = null;
    }
  }

  void _onPurchaseSuccess() {
    final message = _premiumService.purchaseSuccessNotifier.value;
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2E7D32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
            ],
          ),
        ),
      );
      _premiumService.purchaseSuccessNotifier.value = null;
    }
  }

  void _showPrivacyPolicyModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1729) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Icon(Icons.privacy_tip_outlined, color: Color(0xFF7046A8)),
                      SizedBox(width: 10),
                      Text(
                        'Privacy & Security',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'All Documents Reader is engineered with security and user privacy as top priorities.\n\n'
                    '• Local Document Processing: All documents (PDFs, Word files, Excel spreadsheets, presentations, and images) are parsed, rendered, and stored strictly on your local device.\n\n'
                    '• Zero Telemetry on Documents: We never upload, inspect, or transfer your personal files to any external cloud servers.\n\n'
                    '• Purchases & Subscriptions: Transactions are handled directly and securely through the Google Play Store billing engine.',
                    style: TextStyle(fontSize: 13.5, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7046A8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTermsModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1729) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.45,
          expand: false,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Icon(Icons.gavel_rounded, color: Color(0xFF7046A8)),
                      SizedBox(width: 10),
                      Text(
                        'Terms of Service',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Subscriptions and in-app purchases are governed by Google Play standard terms:\n\n'
                    '• Subscriptions automatically renew unless auto-renew is cancelled at least 24 hours before the end of the current period.\n\n'
                    '• You can manage or cancel your subscription at any time in your Google Play account settings (Google Play > Profile > Payments & Subscriptions).\n\n'
                    '• Lifetime licenses provide perpetual access to all current and future Pro features on all Android devices associated with your Google account.',
                    style: TextStyle(fontSize: 13.5, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7046A8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF140F1D) : const Color(0xFFF9F6FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF261D33) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Icon(
              Icons.close_rounded,
              size: 20,
              color: isDark ? Colors.white : const Color(0xFF2D2435),
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _premiumService.restorePurchases(context),
            icon: const Icon(Icons.restore_rounded, size: 16, color: Color(0xFF9C7CD4)),
            label: const Text(
              'Restore',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9C7CD4),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _premiumService.isPremiumNotifier,
        builder: (context, isPremium, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Hero Header
                _buildHeroHeader(isDark, isPremium),

                const SizedBox(height: 20),

                // Notice if opened from a specific tool
                if (widget.highlightBenefitTitle != null && !isPremium) ...[
                  _buildHighlightNotice(widget.highlightBenefitTitle!, isDark),
                  const SizedBox(height: 16),
                ],

                // 2. Premium Benefits List
                _buildBenefitsSection(isDark),

                const SizedBox(height: 24),

                // 3. Plan Cards (Monthly, Yearly, Lifetime)
                if (!isPremium) ...[
                  _buildPlanSelector(isDark),
                  const SizedBox(height: 20),

                  // 4. Upgrade Call-To-Action Button
                  _buildCtaButton(isDark),
                ] else ...[
                  _buildActiveEntitlementCard(isDark),
                ],

                const SizedBox(height: 20),

                // 5. Legal & Disclaimer links
                _buildFooterLinks(isDark),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // WIDGET BUILDERS
  // ===========================================================================

  Widget _buildHeroHeader(bool isDark, bool isPremium) {
    return Column(
      children: [
        // Crown Icon Badge
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPremium
                  ? [const Color(0xFF2E7D32), const Color(0xFF4CAF50)]
                  : [const Color(0xFF7046A8), const Color(0xFF9C27B0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isPremium ? const Color(0xFF4CAF50) : const Color(0xFF7046A8))
                    .withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            isPremium ? Icons.verified_rounded : Icons.workspace_premium_rounded,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        Text(
          isPremium ? 'Premium Active' : 'All Documents Reader PRO',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : const Color(0xFF261D33),
          ),
        ),
        const SizedBox(height: 6),

        Text(
          isPremium
              ? 'All pro tools, smart scanner, and ad-free features are fully unlocked.'
              : 'Unlock advanced PDF tools, smart document scanner, batch OCR, and remove all ads.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: isDark ? const Color(0xFFB3A8C2) : const Color(0xFF6B5E7C),
          ),
        ),
        const SizedBox(height: 14),

        // Status Chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: isPremium
                ? const Color(0xFF2E7D32).withValues(alpha: 0.15)
                : const Color(0xFF7046A8).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPremium
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                  : const Color(0xFF7046A8).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPremium ? Icons.check_circle_rounded : Icons.lock_open_rounded,
                size: 14,
                color: isPremium ? const Color(0xFF2E7D32) : const Color(0xFF7046A8),
              ),
              const SizedBox(width: 6),
              Text(
                isPremium ? 'FULL LICENSE ACTIVE' : 'UPGRADE TO UNLOCK ALL TOOLS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: isPremium ? const Color(0xFF2E7D32) : const Color(0xFF7046A8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightNotice(String toolName, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1BEE7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, color: Color(0xFF8E24AA), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '"$toolName" is a Premium feature. Upgrade below to gain instant unlimited access!',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4A148C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsSection(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E1728) : Colors.white;

    final benefits = [
      (
        Icons.block_rounded,
        '100% Ad-Free Experience',
        'Completely removes banner, interstitial, and promotional ads.',
        const Color(0xFFE53935),
      ),
      (
        Icons.call_merge_rounded,
        'PDF Merge & Split',
        'Combine multiple files or extract exact custom page ranges.',
        const Color(0xFF7B1FA2),
      ),
      (
        Icons.compress_rounded,
        'PDF Compression & Rotation',
        'Shrink heavy documents without losing clarity and fix orientations.',
        const Color(0xFF2E7D32),
      ),
      (
        Icons.document_scanner_rounded,
        'Smart Scanner & Enhancement',
        'Capture receipts, notes, and IDs with edge detection & B&W filters.',
        const Color(0xFF7C3AED),
      ),
      (
        Icons.text_fields_rounded,
        'Batch OCR Text Workspace',
        'Extract editable text from camera scans, images, and PDF pages.',
        const Color(0xFFC2185B),
      ),
      (
        Icons.transform_rounded,
        'Format Converters',
        'Convert Images to PDF, export PDF pages to PNG, and Text to PDF.',
        const Color(0xFF00897B),
      ),
      (
        Icons.security_rounded,
        '100% Private & Local',
        'All tools run locally on your device with complete privacy.',
        const Color(0xFF1976D2),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFECE4F5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EVERYTHING INCLUDED WITH PRO',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Color(0xFF8E7E9E),
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < benefits.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: benefits[i].$4.withValues(alpha: isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(benefits[i].$1, size: 18, color: benefits[i].$4),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          benefits[i].$2,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF2D2435),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          benefits[i].$3,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFFB0A5BE) : const Color(0xFF6E647A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (i < benefits.length - 1)
              Divider(
                height: 12,
                thickness: 0.7,
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3ECF9),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanSelector(bool isDark) {
    return Column(
      children: [
        for (final plan in PremiumService.availablePlans)
          _buildPlanOptionTile(plan, isDark),

        // Helpful indicator when Google Play Console setup is still pending
        ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: _premiumService.productsNotifier,
          builder: (context, products, _) {
            if (products.isEmpty) {
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF261D33) : const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF7046A8).withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF7046A8)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Live prices populate automatically once created in Google Play Console.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF581C87),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildPlanOptionTile(PremiumPlanInfo plan, bool isDark) {
    final isSelected = _selectedProductId == plan.productId;
    final cardBg = isDark ? const Color(0xFF1E1728) : Colors.white;
    final livePrice = _premiumService.getPrice(plan.productId, fallback: '');

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedProductId = plan.productId;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF7046A8)
                : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE4DAEE)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF7046A8).withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Radio circle indicator
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFF7046A8) : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF7046A8)
                      : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),

            // Plan details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF261D33),
                        ),
                      ),
                      if (plan.badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: plan.isBestValue
                                ? const LinearGradient(
                                    colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                                  )
                                : null,
                            color: plan.isBestValue
                                ? null
                                : const Color(0xFF7046A8).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            plan.badge!,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: plan.isBestValue ? Colors.white : const Color(0xFF7046A8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    plan.subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFFB3A8C2) : const Color(0xFF7A6F87),
                    ),
                  ),
                ],
              ),
            ),

            // Price display (Dynamic from Play Store or Setup Notice)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (livePrice.isNotEmpty) ...[
                  Text(
                    livePrice,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7046A8),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2436) : const Color(0xFFF3ECF9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Store Price',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFCBBCE0) : AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCtaButton(bool isDark) {
    return ValueListenableBuilder<bool>(
      valueListenable: _premiumService.isPurchasingNotifier,
      builder: (context, isPurchasing, _) {
        final plan = PremiumService.availablePlans.firstWhere(
          (p) => p.productId == _selectedProductId,
          orElse: () => PremiumService.availablePlans.first,
        );

        return SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7046A8),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFF7046A8).withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: isPurchasing
                ? null
                : () => _premiumService.buyPlan(context, _selectedProductId),
            child: isPurchasing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Connecting to Google Play...',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.flash_on_rounded, size: 20, color: Colors.amberAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Upgrade with ${plan.title}',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildActiveEntitlementCard(bool isDark) {
    final activePlan = _premiumService.activePlanId ?? 'Premium License';
    final purchaseDate = _premiumService.purchaseDate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF172B20) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 40),
          const SizedBox(height: 8),
          const Text(
            'Your Premium License is Active',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Plan: $activePlan'
            '${purchaseDate != null ? ' • Activated ${_formatDate(purchaseDate)}' : ''}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF388E3C)),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2E7D32),
              side: const BorderSide(color: Color(0xFF4CAF50)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Return to App & Tools'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLinks(bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _showPrivacyPolicyModal,
              child: Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF9C8EB2) : const Color(0xFF7A6F87),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const Text('•', style: TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: _showTermsModal,
              child: Text(
                'Terms of Service',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF9C8EB2) : const Color(0xFF7A6F87),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        Text(
          'Subscriptions renew automatically unless cancelled via Google Play Store at least 24 hours before the current period ends.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.35,
            color: isDark ? Colors.grey[500] : const Color(0xFF8F859A),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
