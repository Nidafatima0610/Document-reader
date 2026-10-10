import 'dart:io';

import 'package:all_documents_reader/core/config/app_config.dart';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/views/ai_document_assistant_view.dart';
import 'package:all_documents_reader/views/ocr_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:all_documents_reader/services/document_save_service.dart';
import 'package:all_documents_reader/widgets/document_action_dialogs.dart';
import 'package:all_documents_reader/views/pdf_viewer_screen.dart';
import 'package:share_plus/share_plus.dart';

class DocumentDetailsView extends StatefulWidget {
  final DocumentsModel document;
  final Function(DocumentsModel)? onDocumentDelete;

  const DocumentDetailsView({
    super.key,
    required this.document,
    this.onDocumentDelete,
  });

  @override
  State<DocumentDetailsView> createState() => _DocumentDetailsViewState();
}

class _DocumentDetailsViewState extends State<DocumentDetailsView> {
  final DocumentsStorageService _storageService = DocumentsStorageService();
  final TransformationController _imageController = TransformationController();
  late DocumentsModel _currentDocument;

  @override
  void initState() {
    super.initState();
    _currentDocument = widget.document;
    _storageService.loadFavorites();
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  String _getFileExtension(String fileName) {
    if (!fileName.contains('.')) return 'FILE';
    return fileName.split('.').last.toUpperCase();
  }

  String _getFileSize(String path) {
    if (path.isEmpty) return "Sample Preview File";
    try {
      final file = File(path);
      if (!file.existsSync()) return "File not found on disk";
      final bytes = file.lengthSync();
      if (bytes < 1024) {
        return "$bytes Bytes";
      } else if (bytes < 1024 * 1024) {
        return "${(bytes / 1024).toStringAsFixed(1)} KB";
      } else {
        return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
      }
    } catch (e) {
      return "Unavailable";
    }
  }

  String _formatDateTime(DateTime dateTime) {
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
    final hour = dateTime.hour == 0
        ? 12
        : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '$month ${dateTime.day}, ${dateTime.year} at $hour:$minute $period';
  }

  String _formatOpenedTime(DateTime? dateTime) {
    if (dateTime == null) return "Never opened";

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return "Just now";
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return "$mins ${mins == 1 ? 'minute' : 'minutes'} ago";
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return "$hours ${hours == 1 ? 'hour' : 'hours'} ago";
    } else {
      return _formatDateTime(dateTime);
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
        iconColor: const Color(0xFFD32F2F),
        badgeColor: isDark ? const Color(0xFF3E1A1A) : const Color(0xFFFDE8E8),
        badgeTextColor: const Color(0xFFD32F2F),
        indicatorColor: const Color(0xFFD32F2F),
        label: 'PDF Document',
        formatPill: 'PDF',
      );
    } else if (lowerName.endsWith('.doc') || lowerName.endsWith('.docx')) {
      return _FileTypeStyle(
        icon: Icons.description_rounded,
        iconColor: const Color(0xFF1976D2),
        badgeColor: isDark ? const Color(0xFF152A3F) : const Color(0xFFE3F2FD),
        badgeTextColor: const Color(0xFF1976D2),
        indicatorColor: const Color(0xFF1976D2),
        label: 'Microsoft Word Document',
        formatPill: 'WORD',
      );
    } else if (lowerName.endsWith('.xls') ||
        lowerName.endsWith('.xlsx') ||
        lowerName.endsWith('.csv')) {
      return _FileTypeStyle(
        icon: Icons.table_chart_rounded,
        iconColor: const Color(0xFF2E7D32),
        badgeColor: isDark ? const Color(0xFF17331A) : const Color(0xFFE8F5E9),
        badgeTextColor: const Color(0xFF2E7D32),
        indicatorColor: const Color(0xFF2E7D32),
        label: 'Microsoft Excel Spreadsheet',
        formatPill: 'EXCEL',
      );
    } else if (lowerName.endsWith('.ppt') || lowerName.endsWith('.pptx')) {
      return _FileTypeStyle(
        icon: Icons.slideshow_rounded,
        iconColor: const Color(0xFFE65100),
        badgeColor: isDark ? const Color(0xFF382313) : const Color(0xFFFFF3E0),
        badgeTextColor: const Color(0xFFE65100),
        indicatorColor: const Color(0xFFE65100),
        label: 'PowerPoint Presentation',
        formatPill: 'PPT',
      );
    } else if (lowerName.endsWith('.txt') || lowerName.endsWith('.rtf')) {
      return _FileTypeStyle(
        icon: Icons.article_rounded,
        iconColor: const Color(0xFFF57C00),
        badgeColor: isDark ? const Color(0xFF352B14) : const Color(0xFFFFF8E1),
        badgeTextColor: const Color(0xFFF57C00),
        indicatorColor: const Color(0xFFF57C00),
        label: 'Plain Text Document',
        formatPill: 'TEXT',
      );
    } else if (_isImage(doc)) {
      return _FileTypeStyle(
        icon: Icons.image_rounded,
        iconColor: const Color(0xFF00838F),
        badgeColor: isDark ? const Color(0xFF102E33) : const Color(0xFFE0F7FA),
        badgeTextColor: const Color(0xFF00838F),
        indicatorColor: const Color(0xFF00838F),
        label: 'Image File',
        formatPill: 'IMAGE',
      );
    } else {
      return _FileTypeStyle(
        icon: Icons.insert_drive_file_rounded,
        iconColor: const Color(0xFF7046A8),
        badgeColor: isDark ? const Color(0xFF2B1D3D) : const Color(0xFFF1E7FA),
        badgeTextColor: const Color(0xFF7046A8),
        indicatorColor: const Color(0xFF7046A8),
        label: '${_getFileExtension(doc.name)} File',
        formatPill: _getFileExtension(doc.name),
      );
    }
  }

  void _openDocument() {
    if (_currentDocument.path.isEmpty ||
        !File(_currentDocument.path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentDocument.path.isEmpty
                      ? "Sample '${_currentDocument.name}' is for preview. Add local files to open!"
                      : "File '${_currentDocument.name}' not found on device storage.",
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    _storageService.recordDocumentOpened(_currentDocument);

    if (_currentDocument.type == 'pdf' ||
        _currentDocument.name.toLowerCase().endsWith('.pdf')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            file: File(_currentDocument.path),
            title: _currentDocument.name,
            document: _currentDocument,
          ),
        ),
      );
    } else if (_isImage(_currentDocument)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(_currentDocument.name),
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
                    child: Image.file(
                      File(_currentDocument.path),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      OpenFilex.open(_currentDocument.path);
    }
  }

  Future<void> _handleToggleFavorite() async {
    final isNowFav = await _storageService.toggleFavorite(_currentDocument);
    setState(() {
      _currentDocument = _currentDocument.copyWith(isFavorite: isNowFav);
    });

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

  Future<void> _handleRemoveFromApp() async {
    final removed = await DocumentActionDialogs.showRemoveFromAppDialog(
      context: context,
      document: _currentDocument,
      onRemoved: () {
        widget.onDocumentDelete?.call(_currentDocument);
      },
    );
    if (removed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handleDeletePermanently() async {
    final deleted = await DocumentActionDialogs.showDeletePermanentlyDialog(
      context: context,
      document: _currentDocument,
      onDeleted: () {
        widget.onDocumentDelete?.call(_currentDocument);
      },
    );
    if (deleted == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handleSaveToDevice() async {
    if (_currentDocument.path.isEmpty || !File(_currentDocument.path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found on device storage.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await DocumentSaveService.instance.saveDocumentToDevice(
      context: context,
      sourceFile: File(_currentDocument.path),
      defaultFileName: _currentDocument.name,
    );
  }

  Future<void> _handleShare() async {
    if (_currentDocument.path.isEmpty || !File(_currentDocument.path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found on device storage.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(_currentDocument.path)],
        text: _currentDocument.name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share document: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = _getFileTypeStyle(_currentDocument, isDark);
    final isSample = _currentDocument.path.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Document Details",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        actions: [
          ValueListenableBuilder<Set<String>>(
            valueListenable: _storageService.favoritesNotifier,
            builder: (context, favs, _) {
              final isFav =
                  favs.contains(_currentDocument.id) ||
                  _currentDocument.isFavorite;
              return IconButton(
                icon: Icon(
                  isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isFav
                      ? Colors.amber
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                tooltip: isFav ? "Remove from Favorites" : "Add to Favorites",
                onPressed: _handleToggleFavorite,
              );
            },
          ),
          if (!isSample && File(_currentDocument.path).existsSync()) ...[
            IconButton(
              icon: const Icon(Icons.save_alt_rounded),
              tooltip: "Save to Device",
              onPressed: _handleSaveToDevice,
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: "Share",
              onPressed: _handleShare,
            ),
          ],
          if (!isSample)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                if (value == 'remove') {
                  _handleRemoveFromApp();
                } else if (value == 'delete') {
                  _handleDeletePermanently();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.remove_circle_outline_rounded, size: 20),
                      SizedBox(width: 10),
                      Text('Remove from App'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever_rounded, color: Colors.red.shade700, size: 20),
                      SizedBox(width: 10),
                      Text('Delete File Permanently', style: TextStyle(color: Colors.red.shade700)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. Hero Header Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF211C29) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: style.badgeColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(style.icon, size: 48, color: style.iconColor),
                ),
                const SizedBox(height: 14),
                Text(
                  _currentDocument.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF2D2435),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: style.badgeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    style.formatPill,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: style.badgeTextColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Action Buttons (Open, Favorite, Delete)
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7046A8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 20),
                  label: const Text(
                    "Open Document",
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _openDocument,
                ),
              ),
              const SizedBox(width: 10),
              ValueListenableBuilder<Set<String>>(
                valueListenable: _storageService.favoritesNotifier,
                builder: (context, favs, _) {
                  final isFav =
                      favs.contains(_currentDocument.id) ||
                      _currentDocument.isFavorite;

                  return Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(
                          color: isFav
                              ? Colors.amber.shade700
                              : const Color(0xFF7046A8),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(
                        isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isFav
                            ? Colors.amber.shade700
                            : const Color(0xFF7046A8),
                        size: 20,
                      ),
                      label: Text(
                        isFav ? "Starred" : "Favorite",
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isFav
                              ? Colors.amber.shade800
                              : const Color(0xFF7046A8),
                        ),
                      ),
                      onPressed: _handleToggleFavorite,
                    ),
                  );
                },
              ),
            ],
          ),

          // 2.5 Document Intelligence & Utilities
          if (AppConfig.isAiFeatureEnabled || _isPdf(_currentDocument) || _isImage(_currentDocument)) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF261D33), const Color(0xFF1E1729)]
                      : [const Color(0xFFF3EDFD), const Color(0xFFEFE8FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF7046A8).withValues(alpha: isDark ? 0.35 : 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7046A8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          AppConfig.isAiFeatureEnabled
                              ? Icons.auto_awesome_rounded
                              : Icons.document_scanner_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppConfig.isAiFeatureEnabled
                                  ? "Document Intelligence"
                                  : "Document OCR Extraction",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF2D2435),
                              ),
                            ),
                            Text(
                              AppConfig.isAiFeatureEnabled
                                  ? "Summarize, Q&A, study notes, and text extraction"
                                  : "Extract editable text directly using offline OCR",
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.grey[400] : const Color(0xFF6C6374),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (AppConfig.isAiFeatureEnabled)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7046A8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.psychology_rounded, size: 18),
                            label: const Text(
                              "AI Assistant",
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AiDocumentAssistantView(
                                    initialDocument: _currentDocument,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (_isPdf(_currentDocument) || _isImage(_currentDocument)) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                side: const BorderSide(color: Color(0xFF7046A8)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.document_scanner_rounded, size: 18, color: Color(0xFF7046A8)),
                              label: const Text(
                                "Run OCR",
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7046A8),
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OcrWorkspaceView(
                                      initialPdfPath: _isPdf(_currentDocument) ? _currentDocument.path : null,
                                      initialImagePath: _isImage(_currentDocument) ? _currentDocument.path : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7046A8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.document_scanner_rounded, size: 18),
                        label: const Text(
                          "Run OCR Workspace",
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OcrWorkspaceView(
                                initialPdfPath: _isPdf(_currentDocument) ? _currentDocument.path : null,
                                initialImagePath: _isImage(_currentDocument) ? _currentDocument.path : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // 3. Information Section Title
          Text(
            "File Information",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF2D2435),
            ),
          ),

          const SizedBox(height: 10),

          // 4. File Info Card
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF211C29) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildInfoTile(
                  icon: Icons.category_outlined,
                  title: "File Type",
                  value: style.label,
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildInfoTile(
                  icon: Icons.data_usage_rounded,
                  title: "File Size",
                  value: _getFileSize(_currentDocument.path),
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildInfoTile(
                  icon: Icons.calendar_today_outlined,
                  title: "Date Added",
                  value: _formatDateTime(_currentDocument.createdAt),
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildInfoTile(
                  icon: Icons.history_rounded,
                  title: "Last Opened",
                  value: _formatOpenedTime(_currentDocument.lastOpenedAt),
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildInfoTile(
                  icon: Icons.folder_open_outlined,
                  title: "File Location",
                  value: _currentDocument.path.isNotEmpty
                      ? _currentDocument.path
                      : "Sample Preview Document",
                  isDark: isDark,
                  trailing: _currentDocument.path.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: "Copy path",
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: _currentDocument.path),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                content: const Text(
                                  "File path copied to clipboard",
                                ),
                              ),
                            );
                          },
                        )
                      : null,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 5. Danger Zone / Document Actions
          if (!isSample) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF231920) : const Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.red.shade900.withValues(alpha: 0.5) : Colors.red.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Manage Document",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF2D2435),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Remove this document from the app history or delete its physical file permanently from your device storage.",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.grey[300] : const Color(0xFF4A4458),
                            side: BorderSide(
                              color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                          label: const Text(
                            "Remove",
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          onPressed: _handleRemoveFromApp,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.delete_forever_rounded, size: 18),
                          label: const Text(
                            "Delete File",
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          onPressed: _handleDeletePermanently,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2E243A) : const Color(0xFFF1E7FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF7046A8)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : const Color(0xFF6B6570),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF2D2435),
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? const Color(0xFF2E2738) : const Color(0xFFF0EBF5),
      indent: 52,
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
  final String formatPill;

  const _FileTypeStyle({
    required this.icon,
    required this.iconColor,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.indicatorColor,
    required this.label,
    required this.formatPill,
  });
}
