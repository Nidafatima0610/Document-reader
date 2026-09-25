import 'package:all_documents_reader/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onSearchPressed;

  const HomeAppBar({
    super.key,
    this.onSettingsPressed,
    this.onSearchPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 4);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      titleSpacing: 16,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.description_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "All Documents",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: isDark ? Colors.white : const Color(0xFF251E2D),
                  ),
                ),
                Text(
                  "Reader & Workspace",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFFB5A7C2) : const Color(0xFF786F80),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: IconButton(
            onPressed: onSearchPressed,
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF261F2E) : const Color(0xFFEFE8F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF382C43)
                      : const Color(0xFFE5D9F0),
                  width: 0.8,
                ),
              ),
              child: Icon(
                Icons.search_rounded,
                size: 19,
                color: isDark ? const Color(0xFFC7B1E6) : AppTheme.primaryColor,
              ),
            ),
            tooltip: "Search Documents",
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            onPressed: onSettingsPressed,
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF261F2E) : const Color(0xFFEFE8F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF382C43)
                      : const Color(0xFFE5D9F0),
                  width: 0.8,
                ),
              ),
              child: Icon(
                Icons.settings_outlined,
                size: 19,
                color: isDark ? const Color(0xFFC7B1E6) : AppTheme.primaryColor,
              ),
            ),
            tooltip: "Settings",
          ),
        ),
      ],
    );
  }
}
