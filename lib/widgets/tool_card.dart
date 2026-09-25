import 'package:all_documents_reader/core/theme/app_theme.dart';
import 'package:all_documents_reader/models/tool_item_model.dart';
import 'package:flutter/material.dart';

/// Reusable card displaying a single tool item with icon, title, description, and status
class ToolCard extends StatelessWidget {
  final ToolItemModel tool;
  final VoidCallback onTap;

  const ToolCard({
    super.key,
    required this.tool,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF211C29) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF2D2435);
    final descColor = isDark ? const Color(0xFFB0A9B8) : const Color(0xFF6C6374);

    return Card(
      color: cardBg,
      elevation: isDark ? 2 : 1,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Icon Container + Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tool.accentColor.withValues(alpha: isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      tool.icon,
                      size: 24,
                      color: tool.accentColor,
                    ),
                  ),
                  _buildStatusBadge(isDark),
                ],
              ),
              const SizedBox(height: 12),

              // Tool Title
              Text(
                tool.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),

              // Tool Description
              Expanded(
                child: Text(
                  tool.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: descColor,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Bottom row: format tag + arrow indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2C2536)
                          : const Color(0xFFF2ECF9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '→ ${tool.outputFormat}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFCEBEEA)
                            : AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: descColor.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isDark) {
    if (tool.status == ToolStatus.available) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32).withValues(alpha: isDark ? 0.25 : 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'READY',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
            color: Color(0xFF2E7D32),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF382F45)
            : const Color(0xFFEDE7F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'PLANNED',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
          color: isDark
              ? const Color(0xFFD0C3E6)
              : const Color(0xFF6C4AB6),
        ),
      ),
    );
  }
}
