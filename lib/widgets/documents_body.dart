import 'dart:io';

import 'package:all_documents_reader/core/theme/app_theme.dart';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/settings_service.dart';
import 'package:all_documents_reader/views/document_details_view.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:all_documents_reader/views/pdf_viewer_screen.dart';
import 'package:all_documents_reader/widgets/banner_ad_widget.dart';

class DocumentsBody extends StatefulWidget {
  final List<DocumentsModel> documents;
  final Function(DocumentsModel) onDocumentDelete;
  final DocumentsStorageService? storageService;
  final String? initialCategory;
  final String? initialSearchQuery;

  const DocumentsBody({
    super.key,
    required this.documents,
    required this.onDocumentDelete,
    this.storageService,
    this.initialCategory,
    this.initialSearchQuery,
  });

  @override
  State<DocumentsBody> createState() => _DocumentsBodyState();
}

class _DocumentsBodyState extends State<DocumentsBody> {
  final TextEditingController searchController = TextEditingController();
  final TransformationController imageController = TransformationController();
  late final DocumentsStorageService _storageService;
  String selectedCategory = 'All';

  final List<DocumentsModel> sampleDocuments = [
    DocumentsModel(
      name: 'Sample Document.pdf',
      path: '',
      type: 'pdf',
      createdAt: DateTime(2025, 10, 15),
    ),
    DocumentsModel(
      name: 'Budget Plan.xlsx',
      path: '',
      type: 'office',
      createdAt: DateTime(2025, 10, 18),
    ),
    DocumentsModel(
      name: 'Project Assignment.docx',
      path: '',
      type: 'office',
      createdAt: DateTime(2025, 11, 2),
    ),
    DocumentsModel(
      name: 'Business Presentation.pptx',
      path: '',
      type: 'office',
      createdAt: DateTime(2025, 11, 10),
    ),
    DocumentsModel(
      name: 'Quick Notes.txt',
      path: '',
      type: 'office',
      createdAt: DateTime(2025, 11, 22),
    ),
    DocumentsModel(
      name: 'Vacation Photo.jpg',
      path: '',
      type: 'image',
      createdAt: DateTime(2025, 12, 1),
    ),
  ];

  final List<String> categories = const [
    'All',
    'PDF',
    'Office',
    'Images',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _storageService = widget.storageService ?? DocumentsStorageService();
    _storageService.loadFavorites();
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      selectedCategory = widget.initialCategory!;
    }
    if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
      searchController.text = widget.initialSearchQuery!;
    }
    SettingsService.instance.defaultSortNotifier.addListener(_onSortChanged);
  }

  void _onSortChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant DocumentsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory != null &&
        widget.initialCategory != oldWidget.initialCategory &&
        widget.initialCategory!.isNotEmpty) {
      setState(() {
        selectedCategory = widget.initialCategory!;
      });
    }
    if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery != oldWidget.initialSearchQuery) {
      setState(() {
        searchController.text = widget.initialSearchQuery!;
      });
    }
  }

  @override
  void dispose() {
    SettingsService.instance.defaultSortNotifier.removeListener(_onSortChanged);
    searchController.dispose();
    imageController.dispose();
    super.dispose();
  }

  String _getFileExtension(String fileName) {
    if (!fileName.contains('.')) return 'FILE';
    return fileName.split('.').last.toUpperCase();
  }

  String _formatDate(DateTime dateTime) {
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

  String _getFileSize(DocumentsModel doc) {
    if (doc.path.isNotEmpty && File(doc.path).existsSync()) {
      try {
        final bytes = File(doc.path).lengthSync();
        if (bytes < 1024) return "$bytes B";
        if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
        return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
      } catch (_) {
        return "";
      }
    }
    return "";
  }

  bool _isPdf(DocumentsModel doc) {
    final lowerName = doc.name.toLowerCase();
    return doc.type.toLowerCase() == 'pdf' || lowerName.endsWith('.pdf');
  }

  bool _isOffice(DocumentsModel doc) {
    final lowerName = doc.name.toLowerCase();
    final officeExtensions = [
      '.doc',
      '.docx',
      '.xls',
      '.xlsx',
      '.ppt',
      '.pptx',
      '.txt',
      '.rtf',
      '.csv',
    ];
    if (officeExtensions.any((ext) => lowerName.endsWith(ext))) {
      return true;
    }
    return doc.type.toLowerCase() == 'office';
  }

  bool _isImage(DocumentsModel doc) {
    final lowerName = doc.name.toLowerCase();
    final imageExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.gif',
      '.bmp',
      '.svg',
    ];
    if (imageExtensions.any((ext) => lowerName.endsWith(ext))) {
      return true;
    }
    return doc.type.toLowerCase() == 'image' ||
        doc.type.toLowerCase() == 'imaage';
  }

  bool _isOther(DocumentsModel doc) {
    return !_isPdf(doc) && !_isOffice(doc) && !_isImage(doc);
  }

  bool _matchesCategory(DocumentsModel doc, String category) {
    switch (category) {
      case 'All':
        return true;
      case 'PDF':
        return _isPdf(doc);
      case 'Office':
        return _isOffice(doc);
      case 'Images':
        return _isImage(doc);
      case 'Other':
        return _isOther(doc);
      default:
        return true;
    }
  }

  List<DocumentsModel> get filteredDocuments {
    final uniqueDocsMap = <String, DocumentsModel>{};
    for (final doc in sampleDocuments) {
      uniqueDocsMap[doc.id] = doc;
    }
    for (final doc in widget.documents) {
      uniqueDocsMap[doc.id] = doc;
    }
    final allDocs = uniqueDocsMap.values.toList();
    final sortMode = SettingsService.instance.defaultSortNotifier.value;
    allDocs.sort((a, b) {
      switch (sortMode) {
        case 'oldest':
          return a.createdAt.compareTo(b.createdAt);
        case 'name_asc':
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'name_desc':
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case 'size':
          final sizeA = a.path.isNotEmpty && File(a.path).existsSync()
              ? File(a.path).lengthSync()
              : 0;
          final sizeB = b.path.isNotEmpty && File(b.path).existsSync()
              ? File(b.path).lengthSync()
              : 0;
          return sizeB.compareTo(sizeA);
        case 'recent':
        default:
          return b.createdAt.compareTo(a.createdAt);
      }
    });

    final query = searchController.text.trim().toLowerCase();

    return allDocs.where((doc) {
      final matchesCat = _matchesCategory(doc, selectedCategory);
      if (!matchesCat) return false;

      if (query.isEmpty) return true;

      return doc.name.toLowerCase().contains(query) ||
          _getFileExtension(doc.name).toLowerCase().contains(query);
    }).toList();
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

  void openDocument(DocumentsModel document) {
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
                    widget.onDocumentDelete(document);
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
      if (document.path.isEmpty) {
        _storageService.recordDocumentOpened(document);
      }
      return;
    }

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
              transformationController: imageController,
              minScale: 1.0,
              maxScale: 4.0,
              child: GestureDetector(
                onDoubleTap: () {
                  if (imageController.value.getMaxScaleOnAxis() > 1.0) {
                    imageController.value = Matrix4.identity();
                  } else {
                    imageController.value = Matrix4.diagonal3Values(
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

  void _confirmDelete(DocumentsModel document) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: Colors.red),
              SizedBox(width: 10),
              Text("Delete Document"),
            ],
          ),
          content: Text(
            "Are you sure you want to remove '${document.name}' from your documents list?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                widget.onDocumentDelete(document);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    content: Text("'${document.name}' deleted"),
                  ),
                );
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final docsList = filteredDocuments;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
      children: [
        // 1. Modern Search Bar
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
            controller: searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: "Search by title or extension...",
              hintStyle: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[500],
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF7046A8),
              ),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20),
                      onPressed: () {
                        searchController.clear();
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

        const SizedBox(height: 14),

        // 2. Filter Category Chips (All, PDF, Office, Images, Other)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: categories.map((category) {
              final isSelected = selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    category,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark
                                ? Colors.grey[300]
                                : const Color(0xFF4A3A52)),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF7046A8),
                  backgroundColor: isDark
                      ? const Color(0xFF211C29)
                      : Colors.white,
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF7046A8)
                          : (isDark
                                ? const Color(0xFF332B3D)
                                : const Color(0xFFE2D7EE)),
                      width: 1.2,
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        selectedCategory = category;
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 18),

        // 3. Section Header with Dynamic Document Count
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  selectedCategory == 'All'
                      ? "All Documents"
                      : "$selectedCategory Files",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF2D2435),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF382A4A)
                        : const Color(0xFFF1E7FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${docsList.length}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7046A8),
                    ),
                  ),
                ),
              ],
            ),
            if (searchController.text.isNotEmpty || selectedCategory != 'All')
              GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCategory = 'All';
                    searchController.clear();
                  });
                },
                child: const Text(
                  "Reset",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7046A8),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 12),

        // 4. Document List or Empty State
        if (docsList.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 30),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF211C29) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2E243A)
                        : const Color(0xFFF1E7FA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search_off_rounded,
                    size: 40,
                    color: Color(0xFF7046A8),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "No Documents Found",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF2D2435),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  searchController.text.isNotEmpty
                      ? "No files matched '${searchController.text}' in '$selectedCategory'."
                      : "No documents available under '$selectedCategory'. Tap '+' to add one!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                if (searchController.text.isNotEmpty ||
                    selectedCategory != 'All')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text("Show All Documents"),
                    onPressed: () {
                      setState(() {
                        selectedCategory = 'All';
                        searchController.clear();
                      });
                    },
                  ),
              ],
            ),
          )
        else
          ValueListenableBuilder<Set<String>>(
            valueListenable: _storageService.favoritesNotifier,
            builder: (context, favoriteKeys, _) {
              return Column(
                children: docsList.map((document) {
                  final style = _getFileTypeStyle(document, isDark);
                  final isSample = sampleDocuments.contains(document);
                  final isFav =
                      favoriteKeys.contains(document.id) || document.isFavorite;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF211C29) : Colors.white,
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
                        onTap: () => openDocument(document),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Subtle visual indicator bar
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
                              // Main content
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      // Formatted type icon box
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: style.badgeColor,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          style.icon,
                                          color: style.iconColor,
                                          size: 26,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Title and metadata
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
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF2D2435),
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
                                                    color: style.badgeColor,
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
                                                          FontWeight.bold,
                                                      color:
                                                          style.badgeTextColor,
                                                      letterSpacing: 0.4,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    "•  ${_formatDate(document.createdAt)}${_getFileSize(document).isNotEmpty ? '  •  ${_getFileSize(document)}' : ''}",
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isDark
                                                          ? Colors.grey[400]
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
                                      // Star / Favorite Action Button
                                      IconButton(
                                        iconSize: 22,
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          isFav
                                              ? Icons.star_rounded
                                              : Icons.star_outline_rounded,
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
                                            _handleToggleFavorite(document),
                                      ),
                                      // Trailing menu / options
                                      PopupMenuButton<String>(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        icon: Icon(
                                          Icons.more_vert_rounded,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                          size: 20,
                                        ),
                                        onSelected: (value) {
                                          if (value == 'open') {
                                            openDocument(document);
                                          } else if (value == 'details') {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    DocumentDetailsView(
                                                      document: document,
                                                      onDocumentDelete: widget
                                                          .onDocumentDelete,
                                                    ),
                                              ),
                                            );
                                          } else if (value == 'favorite') {
                                            _handleToggleFavorite(document);
                                          } else if (value == 'delete') {
                                            _confirmDelete(document);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'open',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.visibility_outlined,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text("Open Document"),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'details',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.info_outline_rounded,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text("Document Details"),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'favorite',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  isFav
                                                      ? Icons
                                                            .star_outline_rounded
                                                      : Icons.star_rounded,
                                                  size: 18,
                                                  color: Colors.amber,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  isFav
                                                      ? "Remove from Favorites"
                                                      : "Add to Favorites",
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (!isSample)
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.delete_outline,
                                                    size: 18,
                                                    color: Colors.red,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    "Delete",
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
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
                }).toList(),
              );
            },
          ),

        const SizedBox(height: 16),
        const BannerAdWidget(),
        const SizedBox(
          height: 80,
        ), // Extra scroll room for floating action button
      ],
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
