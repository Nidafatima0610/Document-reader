import 'dart:io';

import 'package:all_documents_reader/core/config/app_config.dart';
import 'package:all_documents_reader/core/theme/app_theme.dart';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/tools_registry_service.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:all_documents_reader/views/pdf_viewer_screen.dart';
import 'package:all_documents_reader/widgets/banner_ad_widget.dart';

class HomeBody extends StatefulWidget {
  final VoidCallback? onSeeAllRecent;
  final ValueChanged<String>? onCategorySelected;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onOpenScanner;
  final VoidCallback? onOpenOcr;
  final VoidCallback? onOpenAiAssistant;
  final VoidCallback? onOpenTools;
  final VoidCallback? onOpenFavorites;

  const HomeBody({
    super.key,
    this.onSeeAllRecent,
    this.onCategorySelected,
    this.onSearchPressed,
    this.onOpenScanner,
    this.onOpenOcr,
    this.onOpenAiAssistant,
    this.onOpenTools,
    this.onOpenFavorites,
  });

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  final DocumentsStorageService _storageService = DocumentsStorageService();

  @override
  void initState() {
    super.initState();
    _storageService.loadRecentDocuments();
    _storageService.loadDocuments();
    _storageService.loadFavorites();
  }

  String _getFileExtension(String fileName) {
    if (!fileName.contains('.')) return 'FILE';
    return fileName.split('.').last.toUpperCase();
  }

  String _formatOpenedTime(DateTime? dateTime) {
    if (dateTime == null) return "Recently opened";

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return "Just now";
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return "$mins ${mins == 1 ? 'min' : 'mins'} ago";
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return "$hours ${hours == 1 ? 'hour' : 'hours'} ago";
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return "$days ${days == 1 ? 'day' : 'days'} ago";
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final month = months[dateTime.month - 1];
      return '$month ${dateTime.day}';
    }
  }

  void _openDocument(BuildContext context, DocumentsModel document) {
    if (document.path.isEmpty || !File(document.path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  document.path.isEmpty
                      ? "Sample '${document.name}' is for preview. Add local files to open!"
                      : "File '${document.name}' not found on device storage.",
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    _storageService.recordDocumentOpened(document);

    if (document.type == 'pdf' || document.name.toLowerCase().endsWith('.pdf')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            file: File(document.path),
            title: document.name,
            document: document,
          ),
        ),
      );
    } else {
      OpenFilex.open(document.path);
    }
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color lightBg,
    required Color darkBg,
    required bool isDark,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: isDark ? darkBg : lightBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? color.withValues(alpha: 0.25)
                  : color.withValues(alpha: 0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : color.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: isDark
                      ? color.withValues(alpha: 0.2)
                      : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF261E2D),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[400] : const Color(0xFF70667A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[400] : const Color(0xFF786F80),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF2D2435),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getDocIcon(DocumentsModel doc) {
    final lower = doc.name.toLowerCase();
    if (doc.type.toLowerCase() == 'pdf' || lower.endsWith('.pdf')) {
      return Icons.picture_as_pdf_rounded;
    } else if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      return Icons.table_chart_rounded;
    } else if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Icons.description_rounded;
    } else if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) {
      return Icons.slideshow_rounded;
    } else if (lower.endsWith('.txt')) {
      return Icons.text_snippet_rounded;
    } else if (doc.type.toLowerCase() == 'image' ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpeg')) {
      return Icons.image_rounded;
    } else {
      return Icons.insert_drive_file_rounded;
    }
  }

  Color _getDocIconColor(DocumentsModel doc) {
    final lower = doc.name.toLowerCase();
    if (doc.type.toLowerCase() == 'pdf' || lower.endsWith('.pdf')) {
      return AppTheme.pdfColor;
    } else if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      return AppTheme.excelColor;
    } else if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return AppTheme.wordColor;
    } else if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) {
      return AppTheme.pptColor;
    } else if (lower.endsWith('.txt')) {
      return AppTheme.textColor;
    } else if (doc.type.toLowerCase() == 'image' ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpeg')) {
      return AppTheme.imageColor;
    } else {
      return AppTheme.primaryColor;
    }
  }

  Widget _buildCategoryCard({
    required String title,
    required IconData icon,
    required Color color,
    required Color lightBg,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF211B28) : lightBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF2E2638)
                  : color.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.22 : 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 26, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF251E2D),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // 1. Search Bar
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF211C29) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2E2638) : const Color(0xFFECE4F5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            readOnly: true,
            onTap: widget.onSearchPressed ?? widget.onSeeAllRecent,
            decoration: InputDecoration(
              hintText: "Search Documents...",
              hintStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400] : Colors.grey[500],
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF7046A8),
                size: 22,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),

        const SizedBox(height: 18),

        // 2. Workspace Actions Hub
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Workspace Actions",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : const Color(0xFF251E2D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                title: "Smart Scanner",
                subtitle: "Scan & OCR",
                icon: Icons.document_scanner_rounded,
                color: const Color(0xFF7046A8),
                lightBg: const Color(0xFFF7F1FB),
                darkBg: const Color(0xFF281E34),
                isDark: isDark,
                onTap: widget.onOpenScanner,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppConfig.isAiFeatureEnabled
                  ? _buildQuickActionCard(
                      title: "AI Assistant",
                      subtitle: "Summary & Q&A",
                      icon: Icons.auto_awesome_rounded,
                      color: const Color(0xFF8E24AA),
                      lightBg: const Color(0xFFFBF1FD),
                      darkBg: const Color(0xFF2D1E36),
                      isDark: isDark,
                      onTap: widget.onOpenAiAssistant,
                    )
                  : _buildQuickActionCard(
                      title: "OCR Workspace",
                      subtitle: "Extract Text",
                      icon: Icons.text_fields_rounded,
                      color: const Color(0xFF8E24AA),
                      lightBg: const Color(0xFFFBF1FD),
                      darkBg: const Color(0xFF2D1E36),
                      isDark: isDark,
                      onTap: widget.onOpenOcr,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                title: "All Tools",
                subtitle: "${ToolsRegistryService.instance.getAllTools().length} Utilities",
                icon: Icons.construction_rounded,
                color: const Color(0xFF1976D2),
                lightBg: const Color(0xFFF0F6FC),
                darkBg: const Color(0xFF182638),
                isDark: isDark,
                onTap: widget.onOpenTools,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickActionCard(
                title: "Favorites",
                subtitle: "Starred files",
                icon: Icons.star_rounded,
                color: const Color(0xFFE65100),
                lightBg: const Color(0xFFFFF7ED),
                darkBg: const Color(0xFF2E2215),
                isDark: isDark,
                onTap: widget.onOpenFavorites,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 3. Document Overview Metrics Bar
        ValueListenableBuilder<List<DocumentsModel>>(
          valueListenable: _storageService.documentsNotifier,
          builder: (context, userDocs, _) {
            final totalCount = userDocs.length + 6;
            return ValueListenableBuilder<List<DocumentsModel>>(
              valueListenable: _storageService.recentDocumentsNotifier,
              builder: (context, recents, _) {
                return ValueListenableBuilder<Set<String>>(
                  valueListenable: _storageService.favoritesNotifier,
                  builder: (context, favs, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF211C29) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2E2638) : const Color(0xFFECE4F5),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Flexible(child: _buildStatItem("Total", "$totalCount Files", Icons.folder_rounded, const Color(0xFF7046A8), isDark)),
                          Container(width: 1, height: 26, color: isDark ? const Color(0xFF332B3D) : const Color(0xFFEDE5F4)),
                          Flexible(child: _buildStatItem("History", "${recents.length} Opened", Icons.history_rounded, const Color(0xFF1976D2), isDark)),
                          Container(width: 1, height: 26, color: isDark ? const Color(0xFF332B3D) : const Color(0xFFEDE5F4)),
                          Flexible(child: _buildStatItem("Starred", "${favs.length} Saved", Icons.star_rounded, const Color(0xFFFFA000), isDark)),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),

        const SizedBox(height: 22),

        // 4. Recent Documents Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Recent Documents",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : const Color(0xFF251E2D),
              ),
            ),
            if (widget.onSeeAllRecent != null)
              TextButton(
                onPressed: widget.onSeeAllRecent,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF7046A8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "See All",
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 18),
                  ],
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // Dynamic Recent Documents list
        ValueListenableBuilder<List<DocumentsModel>>(
          valueListenable: _storageService.recentDocumentsNotifier,
          builder: (context, recents, _) {
            if (recents.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF211C29) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E2638) : const Color(0xFFEDE5F4),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7046A8).withValues(alpha: isDark ? 0.2 : 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        size: 28,
                        color: Color(0xFF7046A8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "No Recent Documents",
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF251E2D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Files you open or convert will appear here for quick access.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : const Color(0xFF786F80),
                      ),
                    ),
                  ],
                ),
              );
            }

            final displayList = recents.take(3).toList();
            return Column(
              children: displayList.map((doc) {
                final icon = _getDocIcon(doc);
                final color = _getDocIconColor(doc);
                final ext = _getFileExtension(doc.name);
                final timeStr = _formatOpenedTime(doc.lastOpenedAt);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildRecentItemTile(
                    title: doc.name,
                    subtitle: "$ext File • $timeStr",
                    icon: icon,
                    iconColor: color,
                    isDark: isDark,
                    onTap: () => _openDocument(context, doc),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 22),

        // 5. Categories Section
        Text(
          "Categories",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : const Color(0xFF251E2D),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          childAspectRatio: 1.15,
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildCategoryCard(
              title: "PDF",
              icon: Icons.picture_as_pdf_rounded,
              color: AppTheme.pdfColor,
              lightBg: const Color(0xFFFDF2F2),
              isDark: isDark,
              onTap: () => widget.onCategorySelected?.call('PDF'),
            ),
            _buildCategoryCard(
              title: "Word",
              icon: Icons.description_rounded,
              color: AppTheme.wordColor,
              lightBg: const Color(0xFFF0F5FC),
              isDark: isDark,
              onTap: () => widget.onCategorySelected?.call('Office'),
            ),
            _buildCategoryCard(
              title: "Excel",
              icon: Icons.table_chart_rounded,
              color: AppTheme.excelColor,
              lightBg: const Color(0xFFF1F8F3),
              isDark: isDark,
              onTap: () => widget.onCategorySelected?.call('Office'),
            ),
            _buildCategoryCard(
              title: "PowerPoint",
              icon: Icons.slideshow_rounded,
              color: AppTheme.pptColor,
              lightBg: const Color(0xFFFFF4ED),
              isDark: isDark,
              onTap: () => widget.onCategorySelected?.call('Office'),
            ),
            _buildCategoryCard(
              title: "Text",
              icon: Icons.text_snippet_rounded,
              color: AppTheme.textColor,
              lightBg: const Color(0xFFFFF8EC),
              isDark: isDark,
              onTap: () => widget.onCategorySelected?.call('Office'),
            ),
            _buildCategoryCard(
              title: "Images",
              icon: Icons.image_rounded,
              color: AppTheme.imageColor,
              lightBg: const Color(0xFFF0F9FA),
              isDark: isDark,
              onTap: () => widget.onCategorySelected?.call('Images'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const BannerAdWidget(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRecentItemTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF211C29) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2638) : const Color(0xFFEDE5F4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF251E2D),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : const Color(0xFF786F80),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
