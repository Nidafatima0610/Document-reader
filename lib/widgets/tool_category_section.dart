import 'package:all_documents_reader/models/tool_item_model.dart';
import 'package:all_documents_reader/widgets/tool_card.dart';
import 'package:flutter/material.dart';

/// Renders a categorized section containing a header and responsive grid of tools
class ToolCategorySection extends StatelessWidget {
  final ToolCategory category;
  final List<ToolItemModel> tools;
  final ValueChanged<ToolItemModel> onToolTap;

  const ToolCategorySection({
    super.key,
    required this.category,
    required this.tools,
    required this.onToolTap,
  });

  @override
  Widget build(BuildContext context) {
    if (tools.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final headerColor = isDark ? Colors.white : const Color(0xFF2D2435);
    final subtitleColor =
        isDark ? const Color(0xFFB0A9B8) : const Color(0xFF7A7382);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF382D49)
                      : const Color(0xFFE3D5F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  category.icon,
                  size: 18,
                  color: isDark
                      ? const Color(0xFFCEBEEA)
                      : const Color(0xFF7046A8),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                category.displayName.toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: headerColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2B2433)
                      : const Color(0xFFEDE7F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${tools.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFCEBEEA)
                        : const Color(0xFF7046A8),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Subtitle description for category
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            category.description,
            style: TextStyle(
              fontSize: 12.5,
              color: subtitleColor,
            ),
          ),
        ),

        // Responsive Tools Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width > 700
                ? 4
                : width > 480
                    ? 3
                    : 2;

            // Aspect ratio calculation to guarantee ample space without vertical overflow
            final childAspectRatio = crossAxisCount >= 3 ? 0.95 : 0.90;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tools.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: childAspectRatio,
              ),
              itemBuilder: (context, index) {
                final tool = tools[index];
                return ToolCard(
                  tool: tool,
                  onTap: () => onToolTap(tool),
                );
              },
            );
          },
        ),

        const SizedBox(height: 22),
      ],
    );
  }
}
