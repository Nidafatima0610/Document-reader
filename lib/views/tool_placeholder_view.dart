import 'package:all_documents_reader/models/tool_item_model.dart';
import 'package:flutter/material.dart';

/// Polished, honest empty/placeholder state view for planned tools
class ToolPlaceholderView extends StatelessWidget {
  final ToolItemModel tool;

  const ToolPlaceholderView({super.key, required this.tool});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryText = isDark ? Colors.white : const Color(0xFF2D2435);
    final secondaryText =
        isDark ? const Color(0xFFB0A9B8) : const Color(0xFF6C6374);
    final cardBg = isDark ? const Color(0xFF211C29) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(tool.title),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),

            // Hero Icon Container
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: tool.accentColor.withValues(alpha: isDark ? 0.25 : 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: tool.accentColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  tool.icon,
                  size: 46,
                  color: tool.accentColor,
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Category pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF382F45)
                    : const Color(0xFFEDE7F6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${tool.category.displayName.toUpperCase()} TOOL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark
                      ? const Color(0xFFD0C3E6)
                      : const Color(0xFF7046A8),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Title
            Text(
              tool.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),

            const SizedBox(height: 8),

            // Description
            Text(
              tool.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: secondaryText,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 24),

            // Honest Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF282035)
                    : const Color(0xFFF7F2FC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF4A3860)
                      : const Color(0xFFDCC8EF),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.engineering_rounded,
                        size: 20,
                        color: isDark
                            ? const Color(0xFFD5BAFF)
                            : const Color(0xFF7046A8),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Under Construction • Planned Feature',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? const Color(0xFFD5BAFF)
                                : const Color(0xFF7046A8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This conversion utility is scheduled for an upcoming step. '
                    'To protect your documents, we never perform mock or fake conversions.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // File Specification Details
            Card(
              color: cardBg,
              elevation: isDark ? 2 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Format Specifications',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSpecRow(
                      label: 'Supported Input',
                      isDark: isDark,
                      content: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tool.supportedInputFormats
                            .map((fmt) => _buildBadge(fmt, isDark))
                            .toList(),
                      ),
                    ),
                    const Divider(height: 20),
                    _buildSpecRow(
                      label: 'Output Format',
                      isDark: isDark,
                      content: _buildBadge(tool.outputFormat, isDark),
                    ),
                    const Divider(height: 20),
                    _buildSpecRow(
                      label: 'Processing Mode',
                      isDark: isDark,
                      content: Text(
                        'Offline / Local on device',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Planned Features Preview Card
            if (tool.features.isNotEmpty)
              Card(
                color: cardBg,
                elevation: isDark ? 2 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.playlist_add_check_rounded,
                            size: 20,
                            color: tool.accentColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Planned Capabilities',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...tool.features.map(
                        (feature) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 16,
                                color: tool.accentColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: secondaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 28),

            // Back button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text(
                  'Back to Tools',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow({
    required String label,
    required bool isDark,
    required Widget content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFFB0A9B8) : const Color(0xFF7A7382),
            ),
          ),
        ),
        Expanded(child: content),
      ],
    );
  }

  Widget _buildBadge(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2536) : const Color(0xFFEFE8F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFCEBEEA) : const Color(0xFF7046A8),
        ),
      ),
    );
  }
}
