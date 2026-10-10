import 'dart:io';

import 'package:all_documents_reader/core/theme/app_theme.dart';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/views/document_details_view.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:all_documents_reader/views/pdf_viewer_screen.dart';
import 'package:all_documents_reader/widgets/document_action_dialogs.dart';

class RecentDocumentsView extends StatefulWidget {
  final VoidCallback? onBrowseDocuments;

  const RecentDocumentsView({super.key, this.onBrowseDocuments});

  @override
  State<RecentDocumentsView> createState() => _RecentDocumentsViewState();
}

class _RecentDocumentsViewState extends State<RecentDocumentsView> {
  final DocumentsStorageService _storageService = DocumentsStorageService();
  final TextEditingController _searchController = TextEditingController();
  final TransformationController _imageController = TransformationController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _storageService.loadRecentDocuments();
    await _storageService.loadFavorites();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _imageController.dispose();
    super.dispose();
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
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final month = months[dateTime.month - 1];
      return '$month ${dateTime.day}, ${dateTime.year}';
    }
  }

  bool _isPdf(DocumentsModel doc) {
    final lower = doc.name.toLowerCase();
    return doc.type.toLowerCase() == 'pdf' || lower.endsWith('.pdf');
  }

  bool _isImage(DocumentsModel doc) {
    final lower = doc.name.toLowerCase();
    final imgExts = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.svg'];
    return imgExts.any((ext) => lower.endsWith(ext)) ||
        doc.type.toLowerCase() == 'image' ||
        doc.type.toLowerCase() == 'imaage';
  }

  _FileTypeStyle _getFileTypeStyle(DocumentsModel doc, bool isDark) {
    final lowerName = doc.name.toLowerCase();

    if (_isPdf(doc)) {
      return _FileTypeStyle(
        icon: Icons.picture_as_pdf_rounded,
        iconColor: AppTheme.pdfColor,
        badgeColor: isDark ? const Color(0xFF3E1A1A) : const Color(0xFFFDE8E8),
        badgeTextColor: AppTheme.pdfColor,
        indicatorColor: AppTheme.pdfColor,
        label: 'PDF',
      );
    } else if (lowerName.endsWith('.doc') || lowerName.endsWith('.docx')) {
      return _FileTypeStyle(
        icon: Icons.description_rounded,
        iconColor: AppTheme.wordColor,
        badgeColor: isDark ? const Color(0xFF152A3F) : const Color(0xFFE3F2FD),
        badgeTextColor: AppTheme.wordColor,
        indicatorColor: AppTheme.wordColor,
        label: 'WORD',
      );
    } else if (lowerName.endsWith('.xls') ||
        lowerName.endsWith('.xlsx') ||
        lowerName.endsWith('.csv')) {
      return _FileTypeStyle(
        icon: Icons.table_chart_rounded,
        iconColor: AppTheme.excelColor,
        badgeColor: isDark ? const Color(0xFF17331A) : const Color(0xFFE8F5E9),
        badgeTextColor: AppTheme.excelColor,
        indicatorColor: AppTheme.excelColor,
        label: 'EXCEL',
      );
    } else if (lowerName.endsWith('.ppt') || lowerName.endsWith('.pptx')) {
      return _FileTypeStyle(
        icon: Icons.slideshow_rounded,
        iconColor: AppTheme.pptColor,
        badgeColor: isDark ? const Color(0xFF382313) : const Color(0xFFFFF3E0),
        badgeTextColor: AppTheme.pptColor,
        indicatorColor: AppTheme.pptColor,
        label: 'PPT',
      );
    } else if (lowerName.endsWith('.txt') || lowerName.endsWith('.rtf')) {
      return _FileTypeStyle(
        icon: Icons.article_rounded,
        iconColor: AppTheme.textColor,
        badgeColor: isDark ? const Color(0xFF352B14) : const Color(0xFFFFF8E1),
        badgeTextColor: AppTheme.textColor,
        indicatorColor: AppTheme.textColor,
        label: 'TEXT',
      );
    } else if (_isImage(doc)) {
      return _FileTypeStyle(
        icon: Icons.image_rounded,
        iconColor: AppTheme.imageColor,
        badgeColor: isDark ? const Color(0xFF102E33) : const Color(0xFFE0F7FA),
        badgeTextColor: AppTheme.imageColor,
        indicatorColor: AppTheme.imageColor,
        label: 'IMAGE',
      );
    } else {
      return _FileTypeStyle(
        icon: Icons.insert_drive_file_rounded,
        iconColor: AppTheme.primaryColor,
        badgeColor: isDark ? const Color(0xFF2B1D3D) : const Color(0xFFF1E7FA),
        badgeTextColor: AppTheme.primaryColor,
        indicatorColor: AppTheme.primaryColor,
        label: _getFileExtension(doc.name),
      );
    }
  }

  void _openDocument(DocumentsModel document) {
    if (document.path.isEmpty || !File(document.path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: (document.path.isNotEmpty)
              ? SnackBarAction(
                  label: "Remove",
                  textColor: Colors.amberAccent,
                  onPressed: () {
                    _storageService.removeRecentDocument(document);
                  },
                )
              : null,
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  document.path.isEmpty
                      ? "Sample '${document.name}' is for preview. Add local files to open!"
                      : "File '${document.name}' not found on device storage.",
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    // Record document open in history
    _storageService.recordDocumentOpened(document);

    if (document.type == 'pdf' ||
        document.name.toLowerCase().endsWith('.pdf')) {
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
    } else if (_isImage(document)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(document.name),
            ),
            body: InteractiveViewer(
              transformationController: _imageController,
              minScale: 1.0,
              maxScale: 4.0,
              child: GestureDetector(
                onDoubleTap: () {
                  if (_imageController.value.getMaxScaleOnAxis() > 1.0) {
                    _imageController.value = Matrix4.identity();
                  } else {
                    _imageController.value = Matrix4.diagonal3Values(
                      2.5,
                      2.5,
                      1.0,
                    );
                  }
                },
                child: Container(
                  color: Colors.black,
                  width: double.infinity,
                  height: double.infinity,
                  child: Center(
                    child: Image.file(File(document.path), fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      OpenFilex.open(document.path);
    }
  }

  Future<void> _handleToggleFavorite(DocumentsModel document) async {
    final isNowFav = await _storageService.toggleFavorite(document);
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1400),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          content: Row(
            children: [
              Icon(
                isNowFav ? Icons.star_rounded : Icons.star_outline_rounded,
                color: Colors.amber,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isNowFav ? "Added to Favorites" : "Removed from Favorites",
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showClearRecentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.history_toggle_off_rounded, color: Color(0xFF7046A8)),
              SizedBox(width: 10),
              Text("Clear Recent"),
            ],
          ),
          content: const Text(
            "Are you sure you want to clear your recently opened documents history? Original files will remain safe.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7046A8),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _storageService.clearRecentDocuments();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      content: const Text("Recent documents history cleared."),
                    ),
                  );
                }
              },
              child: const Text("Clear All"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF382A4A)
                    : const Color(0xFFE8DEF8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 22,
                color: Color(0xFF7046A8),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Recent Documents",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
            ),
          ],
        ),
        actions: [
          ValueListenableBuilder<List<DocumentsModel>>(
            valueListenable: _storageService.recentDocumentsNotifier,
            builder: (context, recents, _) {
              if (recents.isEmpty) return const SizedBox.shrink();
              return Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2C223B)
                          : const Color(0xFFF1E7FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF4A3A5E)
                            : const Color(0xFFD8C2EE),
                      ),
                    ),
                    child: Text(
                      "${recents.length} recent",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7046A8),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: "Clear History",
                    onPressed: () => _showClearRecentDialog(context),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7046A8)),
            )
          : ValueListenableBuilder<List<DocumentsModel>>(
              valueListenable: _storageService.recentDocumentsNotifier,
              builder: (context, recents, _) {
                final query = _searchController.text.trim().toLowerCase();
                final displayedDocs = query.isEmpty
                    ? recents
                    : recents.where((doc) {
                        return doc.name.toLowerCase().contains(query) ||
                            _getFileExtension(
                              doc.name,
                            ).toLowerCase().contains(query);
                      }).toList();

                if (recents.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2E243A)
                                  : const Color(0xFFF1E7FA),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.history_rounded,
                              size: 52,
                              color: Color(0xFF7046A8),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "No Recent Documents",
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF2D2435),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Documents you open will automatically appear here for quick access (up to 10 latest files).",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.4,
                              color: isDark
                                  ? Colors.grey[400]
                                  : const Color(0xFF6B6570),
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (widget.onBrowseDocuments != null)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7046A8),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(
                                Icons.folder_open_rounded,
                                size: 20,
                              ),
                              label: const Text(
                                "Browse Documents",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              onPressed: widget.onBrowseDocuments,
                            ),
                        ],
                      ),
                    ),
                  );
                }

                return ValueListenableBuilder<Set<String>>(
                  valueListenable: _storageService.favoritesNotifier,
                  builder: (context, favKeys, _) {
                    return ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      children: [
                        // Search Bar
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF211C29)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2E2638) : const Color(0xFFECE4F5),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.25 : 0.04,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: "Search in recent documents...",
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[500],
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: Color(0xFF7046A8),
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
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
                        const SizedBox(height: 18),
                        // Section Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Recently Opened",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF2D2435),
                              ),
                            ),
                            Text(
                              "${displayedDocs.length} of ${recents.length}",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.grey[400]
                                    : const Color(0xFF6B6570),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Cards
                        ...displayedDocs.map((document) {
                          final style = _getFileTypeStyle(document, isDark);
                          final isFav =
                              favKeys.contains(document.id) ||
                              document.isFavorite;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF211C29)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF2E2638)
                                    : const Color(0xFFEDE5F4),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.25 : 0.025,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _openDocument(document),
                                child: IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        width: 5,
                                        decoration: BoxDecoration(
                                          color: style.indicatorColor,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(16),
                                            bottomLeft: Radius.circular(16),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: style.badgeColor,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Icon(
                                                  style.icon,
                                                  color: style.iconColor,
                                                  size: 26,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      document.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: isDark
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF2D2435,
                                                              ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: style
                                                                .badgeColor,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  6,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            style.label,
                                                            style: TextStyle(
                                                              fontSize: 10.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: style
                                                                  .badgeTextColor,
                                                              letterSpacing:
                                                                  0.4,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            "•  ${_formatOpenedTime(document.lastOpenedAt)}",
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: isDark
                                                                  ? Colors
                                                                        .grey[400]
                                                                  : const Color(
                                                                      0xFF6B6570,
                                                                    ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                iconSize: 22,
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                constraints:
                                                    const BoxConstraints(),
                                                icon: Icon(
                                                  isFav
                                                      ? Icons.star_rounded
                                                      : Icons
                                                            .star_outline_rounded,
                                                  color: isFav
                                                      ? Colors.amber
                                                      : (isDark
                                                            ? Colors.grey[500]
                                                            : Colors.grey[400]),
                                                ),
                                                tooltip: isFav
                                                    ? "Remove from Favorites"
                                                    : "Add to Favorites",
                                                onPressed: () =>
                                                    _handleToggleFavorite(
                                                      document,
                                                    ),
                                              ),
                                              PopupMenuButton<String>(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                icon: Icon(
                                                  Icons.more_vert_rounded,
                                                  color: isDark
                                                      ? Colors.grey[400]
                                                      : Colors.grey[600],
                                                  size: 20,
                                                ),
                                                onSelected: (value) async {
                                                  if (value == 'open') {
                                                    _openDocument(document);
                                                  } else if (value == 'details') {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            DocumentDetailsView(
                                                              document: document,
                                                            ),
                                                      ),
                                                    );
                                                  } else if (value == 'favorite') {
                                                    _handleToggleFavorite(document);
                                                  } else if (value == 'remove_from_app' || value == 'remove') {
                                                    await DocumentActionDialogs.showRemoveFromAppConfirmation(
                                                      context: context,
                                                      document: document,
                                                    );
                                                  } else if (value == 'delete_permanently') {
                                                    await DocumentActionDialogs.showDeletePermanentlyConfirmation(
                                                      context: context,
                                                      document: document,
                                                    );
                                                  }
                                                },
                                                itemBuilder: (context) =>
                                                    DocumentActionDialogs.buildMenuItems(
                                                  context: context,
                                                  document: document,
                                                  isSample: document.path.isEmpty,
                                                  isFavorite: isFav,
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
                            ),
                          );
                        }),
                        const SizedBox(height: 40),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

class _FileTypeStyle {
  final IconData icon;
  final Color iconColor;
  final Color badgeColor;
  final Color badgeTextColor;
  final Color indicatorColor;
  final String label;

  const _FileTypeStyle({
    required this.icon,
    required this.iconColor,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.indicatorColor,
    required this.label,
  });
}
