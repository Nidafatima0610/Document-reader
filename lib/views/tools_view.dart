import 'package:all_documents_reader/core/theme/app_theme.dart';
import 'package:all_documents_reader/models/tool_item_model.dart';
import 'package:all_documents_reader/services/premium_service.dart';
import 'package:all_documents_reader/services/tools_registry_service.dart';
import 'package:all_documents_reader/views/premium_view.dart';
import 'package:all_documents_reader/views/smart_scanner_view.dart';
import 'package:all_documents_reader/views/tool_placeholder_view.dart';
import 'package:all_documents_reader/widgets/banner_ad_widget.dart';
import 'package:all_documents_reader/widgets/tool_category_section.dart';
import 'package:flutter/material.dart';

/// Main Tools view presenting categorized document utility tools
class ToolsView extends StatefulWidget {
  const ToolsView({super.key});

  @override
  State<ToolsView> createState() => _ToolsViewState();
}

class _ToolsViewState extends State<ToolsView> {
  final ToolsRegistryService _registry = ToolsRegistryService.instance;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  ToolCategory? _selectedCategory; // null represents "All"

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onToolSelected(ToolItemModel tool) {
    if (tool.isPremium && !PremiumService.instance.isPremium) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PremiumView(
            highlightBenefitTitle: tool.title,
          ),
        ),
      );
      return;
    }

    if (tool.routeBuilder != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: tool.routeBuilder!),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ToolPlaceholderView(tool: tool),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allTools = _registry.getAllTools();
    final filteredTools = _registry.searchTools(
      _searchQuery,
      category: _selectedCategory,
    );

    final searchBg = isDark ? const Color(0xFF211C29) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tools'),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const Icon(Icons.construction_rounded),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: PremiumService.instance.isPremiumNotifier,
            builder: (context, isPremium, _) {
              return IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isPremium
                        ? (isDark ? const Color(0xFF1E3A2B) : const Color(0xFFE8F5E9))
                        : (isDark ? const Color(0xFF38234B) : const Color(0xFFF3E5F5)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isPremium
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.5)
                          : const Color(0xFFAB47BC).withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    isPremium
                        ? Icons.verified_rounded
                        : Icons.workspace_premium_rounded,
                    size: 19,
                    color: isPremium
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFE91E63),
                  ),
                ),
                tooltip: isPremium ? 'Premium Active' : 'Upgrade to PRO',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PremiumView()),
                  );
                },
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF382F45)
                      : const Color(0xFFEDE7F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${allTools.length} Tools',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFCEBEEA)
                        : AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Banner introducing Tools
          _buildHeroBanner(isDark),

          const SizedBox(height: 12),

          // Featured Smart Scanner Action Card
          _buildScannerFeaturedCard(isDark),

          const SizedBox(height: 14),

          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: searchBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search tools, e.g. "Merge", "Word"...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF7046A8),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All',
                  isSelected: _selectedCategory == null,
                  onSelected: () {
                    setState(() {
                      _selectedCategory = null;
                    });
                  },
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Create',
                  isSelected: _selectedCategory == ToolCategory.create,
                  onSelected: () {
                    setState(() {
                      _selectedCategory = ToolCategory.create;
                    });
                  },
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Convert',
                  isSelected: _selectedCategory == ToolCategory.convert,
                  onSelected: () {
                    setState(() {
                      _selectedCategory = ToolCategory.convert;
                    });
                  },
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Manage PDF',
                  isSelected: _selectedCategory == ToolCategory.managePdf,
                  onSelected: () {
                    setState(() {
                      _selectedCategory = ToolCategory.managePdf;
                    });
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Tools Screen Banner Ad (prominently placed above tool sections)
          const BannerAdWidget(
            margin: EdgeInsets.only(top: 4, bottom: 12),
          ),

          const SizedBox(height: 8),

          // Content: Categorized Sections or Filtered Results
          if (filteredTools.isEmpty)
            _buildEmptySearchState(isDark)
          else if (_searchQuery.isNotEmpty || _selectedCategory != null)
            // Group the filtered tools by category
            ...ToolCategory.values.map((cat) {
              final catTools =
                  filteredTools.where((t) => t.category == cat).toList();
              if (catTools.isEmpty) return const SizedBox.shrink();
              return ToolCategorySection(
                category: cat,
                tools: catTools,
                onToolTap: _onToolSelected,
              );
            })
          else ...[
            // All tools organized by full categories
            ToolCategorySection(
              category: ToolCategory.create,
              tools: _registry.getToolsByCategory(ToolCategory.create),
              onToolTap: _onToolSelected,
            ),
            ToolCategorySection(
              category: ToolCategory.convert,
              tools: _registry.getToolsByCategory(ToolCategory.convert),
              onToolTap: _onToolSelected,
            ),
            ToolCategorySection(
              category: ToolCategory.managePdf,
              tools: _registry.getToolsByCategory(ToolCategory.managePdf),
              onToolTap: _onToolSelected,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF342347), const Color(0xFF20172D)]
              : [const Color(0xFFE9DCF7), const Color(0xFFF4ECFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF4C3667) : const Color(0xFFDCC8EF),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF533B71)
                  : AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_fix_high_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All-in-One Document Utilities',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF2D2435),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Create, convert, and manage your documents offline with speed and privacy.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFFC7BED1)
                        : const Color(0xFF6C6374),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerFeaturedCard(bool isDark) {
    return ValueListenableBuilder<bool>(
      valueListenable: PremiumService.instance.isPremiumNotifier,
      builder: (context, isPremium, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (!isPremium) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PremiumView(
                      highlightBenefitTitle: 'Smart Scanner',
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SmartScannerView(),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF5B21B6), const Color(0xFF7C3AED)]
                      : [const Color(0xFF6D28D9), const Color(0xFF8B5CF6)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(
                      alpha: isDark ? 0.35 : 0.25,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.document_scanner_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Smart Scanner',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isPremium
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFF8E24AA),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isPremium ? 'UNLOCKED' : 'PRO',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Scan physical documents, crop, clean B&W & run OCR',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPremium
                          ? Icons.arrow_forward_rounded
                          : Icons.lock_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    required bool isDark,
  }) {
    final activeBg =
        isDark ? AppTheme.primaryLight : AppTheme.primaryColor;
    final inactiveBg =
        isDark ? const Color(0xFF211C29) : Colors.white;
    final activeText =
        isDark ? const Color(0xFF15121A) : Colors.white;
    final inactiveText =
        isDark ? const Color(0xFFD0CBD5) : const Color(0xFF4A3A52);

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? activeText : inactiveText,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: activeBg,
      backgroundColor: inactiveBg,
      elevation: isSelected ? 2 : 0,
      pressElevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Colors.transparent
              : isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
        ),
      ),
    );
  }

  Widget _buildEmptySearchState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 54,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No Tools Found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2D2435),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No tools match "$_searchQuery". Try searching for another term.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
