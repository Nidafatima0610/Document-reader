import 'dart:io';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/models/scanned_page_model.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/pdf_generator_service.dart';
import 'package:all_documents_reader/services/scanner_image_processing_service.dart';
import 'package:all_documents_reader/views/manual_crop_view.dart';
import 'package:all_documents_reader/views/scanner_result_view.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:all_documents_reader/views/pdf_viewer_screen.dart';

/// Smart Scanner Hub & Multi-Page Scanning Workspace
class SmartScannerView extends StatefulWidget {
  const SmartScannerView({super.key});

  @override
  State<SmartScannerView> createState() => _SmartScannerViewState();
}

class _SmartScannerViewState extends State<SmartScannerView> {
  final ImagePicker _picker = ImagePicker();
  final List<ScannedPageModel> _pages = [];
  int _currentPageIndex = 0;

  bool _isProcessing = false;
  String _processingMessage = '';
  List<DocumentsModel> _recentScans = [];
  bool _isLoadingRecent = true;

  @override
  void initState() {
    super.initState();
    _loadRecentScans();
  }

  Future<void> _loadRecentScans() async {
    try {
      final allDocs = await DocumentsStorageService.instance.loadDocuments();
      final scans = allDocs.where((doc) {
        final name = doc.name.toLowerCase();
        return doc.type.toLowerCase() == 'pdf' &&
            (name.startsWith('scanned_') || name.contains('scan'));
      }).toList();

      // Sort newest first
      scans.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _recentScans = scans;
          _isLoadingRecent = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingRecent = false;
        });
      }
    }
  }

  // --- Image Capture & Import Actions ---

  Future<void> _captureFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );

      if (photo != null) {
        _addPageFromPath(photo.path);
      }
    } catch (e) {
      _showErrorSnackBar('Camera error: $e');
    }
  }

  Future<void> _importFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 95,
      );

      if (images.isNotEmpty) {
        for (final img in images) {
          _addPageFromPath(img.path);
        }
      }
    } catch (e) {
      _showErrorSnackBar('Gallery error: $e');
    }
  }

  void _addPageFromPath(String path) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final page = ScannedPageModel(
      id: id,
      originalImagePath: path,
      processedImagePath: path,
      currentFilter: DocumentFilterType.original,
    );

    setState(() {
      _pages.add(page);
      _currentPageIndex = _pages.length - 1;
    });
  }

  void _showAddPageDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Add Scanned Page',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  title: const Text('Capture with Camera'),
                  subtitle: const Text('Take a photo of a document page'),
                  onTap: () {
                    Navigator.pop(context);
                    _captureFromCamera();
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: Colors.blue,
                    ),
                  ),
                  title: const Text('Import from Gallery'),
                  subtitle: const Text('Choose document images from gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _importFromGallery();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Page Manipulations ---

  Future<void> _applyFilterToCurrentPage(DocumentFilterType filter) async {
    if (_pages.isEmpty || _isProcessing) return;
    final page = _pages[_currentPageIndex];
    if (page.currentFilter == filter) return;

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Applying ${filter.label} filter...';
    });

    try {
      final now = DateTime.now().microsecondsSinceEpoch;
      final parentDir = File(page.originalImagePath).parent.path;
      final outPath = '$parentDir/filtered_${filter.name}_$now.jpg';

      final filteredFile = await ScannerImageProcessingService.instance.applyFilter(
        inputPath: page.originalImagePath,
        filter: filter,
        outputPath: outPath,
      );

      if (!mounted) return;
      setState(() {
        _pages[_currentPageIndex] = page.copyWith(
          processedImagePath: filteredFile.path,
          currentFilter: filter,
        );
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      _showErrorSnackBar('Failed to apply filter: $e');
    }
  }

  Future<void> _cropCurrentPage() async {
    if (_pages.isEmpty || _isProcessing) return;
    final page = _pages[_currentPageIndex];

    final croppedPath = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (context) => ManualCropView(
          imagePath: page.originalImagePath,
        ),
      ),
    );

    if (croppedPath != null && mounted) {
      setState(() {
        _isProcessing = true;
        _processingMessage = 'Updating cropped page...';
      });

      try {
        String finalProcessedPath = croppedPath;

        // Reapply the active filter on the newly cropped image
        if (page.currentFilter != DocumentFilterType.original) {
          final now = DateTime.now().microsecondsSinceEpoch;
          final parentDir = File(croppedPath).parent.path;
          final outFilterPath = '$parentDir/crop_filt_${page.currentFilter.name}_$now.jpg';

          final filteredFile = await ScannerImageProcessingService.instance.applyFilter(
            inputPath: croppedPath,
            filter: page.currentFilter,
            outputPath: outFilterPath,
          );
          finalProcessedPath = filteredFile.path;
        }

        if (!mounted) return;
        setState(() {
          _pages[_currentPageIndex] = page.copyWith(
            originalImagePath: croppedPath,
            processedImagePath: finalProcessedPath,
          );
          _isProcessing = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
        });
        _showErrorSnackBar('Failed to reprocess crop: $e');
      }
    }
  }

  Future<void> _rotateCurrentPage() async {
    if (_pages.isEmpty || _isProcessing) return;
    final page = _pages[_currentPageIndex];

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Rotating page...';
    });

    try {
      final now = DateTime.now().microsecondsSinceEpoch;
      final parentDir = File(page.processedImagePath).parent.path;
      final outPath = '$parentDir/rotated_90_$now.jpg';

      final rotatedFile = await ScannerImageProcessingService.instance.rotateImage(
        inputPath: page.processedImagePath,
        degrees: 90,
        outputPath: outPath,
      );

      final newOriginalOut = '$parentDir/orig_rot_90_$now.jpg';
      final rotatedOriginal = await ScannerImageProcessingService.instance.rotateImage(
        inputPath: page.originalImagePath,
        degrees: 90,
        outputPath: newOriginalOut,
      );

      if (!mounted) return;
      setState(() {
        _pages[_currentPageIndex] = page.copyWith(
          originalImagePath: rotatedOriginal.path,
          processedImagePath: rotatedFile.path,
          rotationDegrees: (page.rotationDegrees + 90) % 360,
        );
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      _showErrorSnackBar('Failed to rotate: $e');
    }
  }

  void _deleteCurrentPage() {
    if (_pages.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Page?'),
        content: Text('Remove page ${_currentPageIndex + 1} from this scan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _pages.removeAt(_currentPageIndex);
                if (_currentPageIndex >= _pages.length) {
                  _currentPageIndex = _pages.isNotEmpty ? _pages.length - 1 : 0;
                }
              });
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _movePage(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _pages.length) return;
    setState(() {
      final item = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, item);
      _currentPageIndex = newIndex;
    });
  }

  // --- PDF Compilation and Document Saving ---

  Future<void> _compilePdfAndSave() async {
    if (_pages.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Compiling ${_pages.length} pages into PDF...';
    });

    try {
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final fileName = 'Scanned_Document_$stamp.pdf';

      final imagePaths = _pages.map((p) => p.processedImagePath).toList();

      final pdfResult = await PdfGeneratorService.instance.generatePdfFromImages(
        imagePaths: imagePaths,
        customFileName: fileName,
      );

      final document = DocumentsModel(
        name: pdfResult.fileName,
        path: pdfResult.file.path,
        type: 'pdf',
        createdAt: DateTime.now(),
      );

      await DocumentsStorageService.instance.addDocument(document);

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });

      // Navigate to scanner results
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ScannerResultView(
            pdfResult: pdfResult,
            document: document,
            pages: List.from(_pages),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      _showErrorSnackBar('Failed to compile PDF: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  void _openRecentPdf(DocumentsModel doc) {
    if (doc.path.isEmpty || !File(doc.path).existsSync()) {
      _showErrorSnackBar("File '${doc.name}' not found on device storage.");
      return;
    }

    DocumentsStorageService.instance.recordDocumentOpened(doc);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          file: File(doc.path),
          title: doc.name,
          document: doc,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_pages.isEmpty) {
      return _buildScannerHub(theme, isDark);
    } else {
      return _buildWorkspace(theme, isDark);
    }
  }

  // --- 1. SCANNER HUB (Initial State) ---

  Widget _buildScannerHub(ThemeData theme, bool isDark) {
    final primaryColor = theme.primaryColor;
    final primaryText = isDark ? Colors.white : const Color(0xFF2D2435);
    final secondaryText = isDark ? const Color(0xFFB0A9B8) : const Color(0xFF6C6374);
    final cardBg = isDark ? const Color(0xFF211C29) : Colors.white;
    final surfaceBg = isDark ? const Color(0xFF16121E) : const Color(0xFFF7F6FA);

    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        title: const Text('Smart Scanner'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Hero Banner
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF4C1D95), const Color(0xFF7C3AED)]
                      : [const Color(0xFF6D28D9), const Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Document Scanner',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Capture clean, high-contrast documents, manually crop boundaries, apply real document filters, compile multi-page PDFs & extract text via OCR.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Capture Actions
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _captureFromCamera,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              color: primaryColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Scan Document',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Use device camera',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: InkWell(
                    onTap: _importFromGallery,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.photo_library_rounded,
                              color: Colors.blue,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'From Gallery',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Import photo files',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Feature Highlights
            Row(
              children: [
                _buildMiniFeatureBadge(
                  icon: Icons.crop_rotate_rounded,
                  label: 'Manual Crop',
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildMiniFeatureBadge(
                  icon: Icons.filter_b_and_w_rounded,
                  label: 'B&W & Clean',
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildMiniFeatureBadge(
                  icon: Icons.text_snippet_rounded,
                  label: 'On-Device OCR',
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Recent Scanned Documents Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Scans',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
                if (_recentScans.isNotEmpty)
                  Text(
                    '${_recentScans.length} saved',
                    style: TextStyle(
                      fontSize: 13,
                      color: secondaryText,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            if (_isLoadingRecent)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_recentScans.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.document_scanner_outlined,
                      size: 40,
                      color: secondaryText.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No scanned documents yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "Scan Document" above to start your first scan',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryText.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentScans.length > 5 ? 5 : _recentScans.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final doc = _recentScans[index];
                  final file = File(doc.path);
                  final exists = file.existsSync();
                  final sizeKb = exists ? (file.lengthSync() / 1024).toStringAsFixed(1) : '0';

                  return Material(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        doc.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryText,
                        ),
                      ),
                      subtitle: Text(
                        '$sizeKb KB • ${doc.createdAt.month}/${doc.createdAt.day}/${doc.createdAt.year}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryText,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () => _openRecentPdf(doc),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniFeatureBadge({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF211C29) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Theme.of(context).primaryColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. MULTI-PAGE WORKSPACE (Editing State) ---

  Widget _buildWorkspace(ThemeData theme, bool isDark) {
    final primaryColor = theme.primaryColor;
    final primaryText = isDark ? Colors.white : const Color(0xFF2D2435);
    final cardBg = isDark ? const Color(0xFF211C29) : Colors.white;
    final surfaceBg = isDark ? const Color(0xFF16121E) : const Color(0xFFF7F6FA);

    final currentPage = _pages[_currentPageIndex];

    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Exit Scanner?'),
                content: const Text('Discard current unscanned pages and exit to scanner home?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Keep Editing'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _pages.clear();
                        _currentPageIndex = 0;
                      });
                    },
                    child: const Text('Discard', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        ),
        title: Text(
          'Page ${_currentPageIndex + 1} of ${_pages.length}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _isProcessing ? null : _compilePdfAndSave,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text(
                'Save PDF',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Main Image Preview Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Center(
                      child: Image.file(
                        File(currentPage.processedImagePath),
                        fit: BoxFit.contain,
                        key: ValueKey(
                          '${currentPage.processedImagePath}_${currentPage.currentFilter.name}_${currentPage.rotationDegrees}',
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Page Editing Toolbar (Crop, Rotate, Delete, Reorder)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.crop_rounded),
                      tooltip: 'Crop Page',
                      onPressed: _isProcessing ? null : _cropCurrentPage,
                    ),
                    IconButton(
                      icon: const Icon(Icons.rotate_right_rounded),
                      tooltip: 'Rotate 90°',
                      onPressed: _isProcessing ? null : _rotateCurrentPage,
                    ),
                    if (_pages.length > 1) ...[
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                        tooltip: 'Move Left',
                        onPressed: _currentPageIndex > 0
                            ? () => _movePage(_currentPageIndex, _currentPageIndex - 1)
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        tooltip: 'Move Right',
                        onPressed: _currentPageIndex < _pages.length - 1
                            ? () => _movePage(_currentPageIndex, _currentPageIndex + 1)
                            : null,
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      tooltip: 'Delete Page',
                      onPressed: _isProcessing ? null : _deleteCurrentPage,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Document Filter Selector
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: DocumentFilterType.values.map((filter) {
                    final isSelected = currentPage.currentFilter == filter;
                    return Expanded(
                      child: InkWell(
                        onTap: () => _applyFilterToCurrentPage(filter),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? primaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            filter.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 10),

              // Bottom Multi-Page Thumbnail Carousel & Add Page Button
              Container(
                height: 84,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: isDark ? const Color(0xFF1E1926) : const Color(0xFFEFEBF5),
                child: Row(
                  children: [
                    // Thumbnails list
                    Expanded(
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _pages.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final page = _pages[index];
                          final isSelected = index == _currentPageIndex;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _currentPageIndex = index;
                              });
                            },
                            child: Container(
                              width: 50,
                              height: 68,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? primaryColor : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(
                                      File(page.processedImagePath),
                                      fit: BoxFit.cover,
                                    ),
                                    Positioned(
                                      top: 2,
                                      left: 2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.6),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Add Page Button
                    InkWell(
                      onTap: _showAddPageDialog,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 50,
                        height: 68,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.4),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: primaryColor,
                              size: 24,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Add',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Processing Loading Overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 14),
                      Text(
                        _processingMessage,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
