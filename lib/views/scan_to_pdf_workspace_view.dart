import 'dart:io';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/models/scanned_page_model.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/pdf_generator_service.dart';
import 'package:all_documents_reader/services/scanner_image_processing_service.dart';
import 'package:all_documents_reader/views/pdf_viewer_screen.dart';
import 'package:all_documents_reader/views/scan_to_pdf_camera_view.dart';
import 'package:all_documents_reader/views/scan_to_pdf_editor_view.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

/// Central multi-page management workspace for the Scan to PDF feature.
/// Supports multi-page capture, thumbnail reordering, per-page rotation & editing,
/// PDF generation with custom naming, integration into DocumentsStorageService,
/// and instant PDF opening & sharing.
class ScanToPdfWorkspaceView extends StatefulWidget {
  final List<ScannedPageModel>? initialPages;

  const ScanToPdfWorkspaceView({
    super.key,
    this.initialPages,
  });

  @override
  State<ScanToPdfWorkspaceView> createState() => _ScanToPdfWorkspaceViewState();
}

class _ScanToPdfWorkspaceViewState extends State<ScanToPdfWorkspaceView> {
  final List<ScannedPageModel> _pages = [];
  int _currentPageIndex = 0;

  bool _isProcessing = false;
  String _processingMessage = '';
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.initialPages != null && widget.initialPages!.isNotEmpty) {
      _pages.addAll(widget.initialPages!);
    } else {
      // Auto-launch camera scanner on initial fresh open after frame renders
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.isEmpty) {
          _openCameraScanner();
        }
      });
    }
  }

  // ===========================================================================
  // CAMERA & GALLERY CAPTURE
  // ===========================================================================

  Future<void> _openCameraScanner() async {
    final ScannedPageModel? newPage = await Navigator.push<ScannedPageModel>(
      context,
      MaterialPageRoute(
        builder: (context) => ScanToPdfCameraView(
          existingPages: List.unmodifiable(_pages),
        ),
      ),
    );

    if (newPage != null && mounted) {
      setState(() {
        _pages.add(newPage);
        _currentPageIndex = _pages.length - 1;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 95,
      );

      if (images.isNotEmpty && mounted) {
        for (final imgFile in images) {
          final newPage = ScannedPageModel(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            originalImagePath: imgFile.path,
            processedImagePath: imgFile.path,
            currentFilter: DocumentFilterType.original,
          );
          _pages.add(newPage);
        }

        setState(() {
          _currentPageIndex = _pages.length - 1;
        });
      }
    } catch (e) {
      debugPrint('[ScanToPdfWorkspaceView] Gallery pick error: $e');
      if (mounted) {
        _showSnackBar('Could not import images from gallery: $e');
      }
    }
  }

  void _showAddPageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1A24) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text(
                'Add Page to Document',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: theme.primaryColor.withValues(alpha: 0.08),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: theme.primaryColor,
                  ),
                ),
                title: const Text(
                  'Capture with Camera',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Scan physical document page'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openCameraScanner();
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: Colors.blue.withValues(alpha: 0.08),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: Colors.blue,
                  ),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Select existing photos or scans'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // PER-PAGE ACTIONS (ROTATE, CROP, RETAKE, DELETE, REORDER)
  // ===========================================================================

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

      final outProc = '$parentDir/work_rot_$now.jpg';
      final rotatedProc = await ScannerImageProcessingService.instance.rotateImage(
        inputPath: page.processedImagePath,
        degrees: 90,
        outputPath: outProc,
      );

      final outOrig = '$parentDir/work_orig_rot_$now.jpg';
      final rotatedOrig = await ScannerImageProcessingService.instance.rotateImage(
        inputPath: page.originalImagePath,
        degrees: 90,
        outputPath: outOrig,
      );

      if (mounted) {
        setState(() {
          _pages[_currentPageIndex] = page.copyWith(
            originalImagePath: rotatedOrig.path,
            processedImagePath: rotatedProc.path,
            rotationDegrees: (page.rotationDegrees + 90) % 360,
          );
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('[ScanToPdfWorkspaceView] Rotation error: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _showSnackBar('Failed to rotate: $e');
      }
    }
  }

  Future<void> _editCurrentPage() async {
    if (_pages.isEmpty || _isProcessing) return;
    final page = _pages[_currentPageIndex];

    final ScannedPageModel? updatedPage = await Navigator.push<ScannedPageModel>(
      context,
      MaterialPageRoute(
        builder: (context) => ScanToPdfEditorView(
          imagePath: page.originalImagePath,
          pageNumber: _currentPageIndex + 1,
        ),
      ),
    );

    if (updatedPage != null && mounted) {
      setState(() {
        _pages[_currentPageIndex] = updatedPage;
      });
    }
  }

  Future<void> _retakeCurrentPage() async {
    if (_pages.isEmpty || _isProcessing) return;

    final ScannedPageModel? newPage = await Navigator.push<ScannedPageModel>(
      context,
      MaterialPageRoute(
        builder: (context) => ScanToPdfCameraView(
          existingPages: List.unmodifiable(_pages),
        ),
      ),
    );

    if (newPage != null && mounted) {
      setState(() {
        _pages[_currentPageIndex] = newPage;
      });
    }
  }

  void _confirmDeleteCurrentPage() {
    if (_pages.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Page?'),
        content: Text(
          'Are you sure you want to remove Page ${_currentPageIndex + 1} from this scan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _pages.removeAt(_currentPageIndex);
                if (_currentPageIndex >= _pages.length) {
                  _currentPageIndex = _pages.isNotEmpty ? _pages.length - 1 : 0;
                }
              });
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _movePageLeft() {
    if (_currentPageIndex > 0) {
      setState(() {
        final item = _pages.removeAt(_currentPageIndex);
        _pages.insert(_currentPageIndex - 1, item);
        _currentPageIndex = _currentPageIndex - 1;
      });
    }
  }

  void _movePageRight() {
    if (_currentPageIndex < _pages.length - 1) {
      setState(() {
        final item = _pages.removeAt(_currentPageIndex);
        _pages.insert(_currentPageIndex + 1, item);
        _currentPageIndex = _currentPageIndex + 1;
      });
    }
  }

  // ===========================================================================
  // PDF CREATION, NAMING, SAVING & SHARING
  // ===========================================================================

  void _promptPdfCreation() {
    if (_pages.isEmpty) {
      _showSnackBar('Please scan or import at least one page first.');
      return;
    }

    final now = DateTime.now();
    final defaultStamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final initialName = 'Scanned_Document_$defaultStamp';

    final textController = TextEditingController(text: initialName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF7046A8)),
            SizedBox(width: 10),
            Text('Create PDF', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Convert ${_pages.length} scanned ${_pages.length == 1 ? "page" : "pages"} into a single PDF document.',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Document Name',
                suffixText: '.pdf',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF7046A8), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7046A8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final rawName = textController.text.trim();
              Navigator.pop(ctx);
              _generateAndSavePdf(rawName.isEmpty ? initialName : rawName);
            },
            child: const Text('Save & Export'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndSavePdf(String requestedName) async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Generating PDF from ${_pages.length} pages...';
    });

    try {
      // 1. Sanitize filename (strip invalid filesystem characters)
      String cleanName = requestedName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      if (!cleanName.toLowerCase().endsWith('.pdf')) {
        cleanName = '$cleanName.pdf';
      }

      // 2. Compile PDF using PdfGeneratorService
      final imagePaths = _pages.map((p) => p.processedImagePath).toList();

      final pdfResult = await PdfGeneratorService.instance.generatePdfFromImages(
        imagePaths: imagePaths,
        customFileName: cleanName,
      );

      // 3. Save into existing DocumentsStorageService
      final document = DocumentsModel(
        name: pdfResult.fileName,
        path: pdfResult.file.path,
        type: 'pdf',
        createdAt: DateTime.now(),
      );

      await DocumentsStorageService.instance.addDocument(document);
      await DocumentsStorageService.instance.recordDocumentOpened(document);

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });

      // 4. Show success modal with Open, Share, Done
      _showSuccessDialog(document, pdfResult);
    } catch (e) {
      debugPrint('[ScanToPdfWorkspaceView] PDF generation failed: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _showSnackBar('Failed to generate PDF: $e');
      }
    }
  }

  void _showSuccessDialog(DocumentsModel document, PdfGenerationResult pdfResult) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1A24) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFEDF7ED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32),
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'PDF Created Successfully!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '${document.name} • ${pdfResult.pageCount} pages • ${pdfResult.formattedSize}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  // Open PDF action
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7046A8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PdfViewerScreen(
                              file: pdfResult.file,
                              title: document.name,
                              document: document,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chrome_reader_mode_rounded, size: 18),
                      label: const Text(
                        'Open PDF',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Share action
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF7046A8),
                        side: const BorderSide(color: Color(0xFF7046A8)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        try {
                          // ignore: deprecated_member_use
                          await Share.shareXFiles(
                            [XFile(document.path)],
                            text: 'Scanned Document: ${document.name}',
                          );
                        } catch (e) {
                          debugPrint('Share error: $e');
                        }
                      },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text(
                        'Share',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Done action (returns to Tools / previous screen)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close sheet
                    Navigator.pop(context); // Exit workspace
                  },
                  child: const Text('Done & Return to Tools'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  // ===========================================================================
  // UI BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: _pages.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _pages.isNotEmpty) {
          _confirmDiscardSession();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF131018) : const Color(0xFFF7F6FA),
        appBar: AppBar(
          title: Text(
            _pages.isEmpty ? 'Scan to PDF' : 'Scan to PDF (${_pages.length} Pages)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            if (_pages.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded),
                tooltip: 'Clear All Pages',
                onPressed: _confirmDiscardSession,
              ),
          ],
        ),
        body: Stack(
          children: [
            _pages.isEmpty
                ? _buildEmptyState(theme, isDark)
                : _buildMultiPageWorkspace(theme, isDark),

            // Loading / Processing Overlay
            if (_isProcessing)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF261F33) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF7046A8)),
                        const SizedBox(height: 16),
                        Text(
                          _processingMessage,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _pages.isNotEmpty ? _buildBottomBar(theme) : null,
      ),
    );
  }

  void _confirmDiscardSession() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Scanned Pages?'),
        content: const Text(
          'All unscanned pages in this session will be lost. Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Discard', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF7046A8).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                color: Color(0xFF7046A8),
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Pages Scanned Yet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Capture physical document pages using your phone camera or select images from your gallery to create a multi-page PDF.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7046A8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              onPressed: _openCameraScanner,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text(
                'Open Camera Scanner',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7046A8),
                side: const BorderSide(color: Color(0xFF7046A8), width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text(
                'Import from Gallery',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiPageWorkspace(ThemeData theme, bool isDark) {
    final currentPage = _pages[_currentPageIndex];

    return Column(
      children: [
        // 1. Page Header & Quick Reorder Controls
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? const Color(0xFF1E1A24) : Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7046A8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Page ${_currentPageIndex + 1} of ${_pages.length}',
                      style: const TextStyle(
                        color: Color(0xFF7046A8),
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      currentPage.currentFilter.label,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    tooltip: 'Move Left',
                    onPressed: _currentPageIndex > 0 ? _movePageLeft : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    tooltip: 'Move Right',
                    onPressed: _currentPageIndex < _pages.length - 1
                        ? _movePageRight
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. Central Active Page Preview
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  File(currentPage.processedImagePath),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.broken_image_rounded, size: 64, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 3. Per-Page Toolbar (Rotate, Crop, Retake, Delete)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1A24) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPageActionBtn(
                icon: Icons.rotate_right_rounded,
                label: 'Rotate',
                onTap: _rotateCurrentPage,
              ),
              _buildPageActionBtn(
                icon: Icons.crop_rounded,
                label: 'Crop/Filter',
                onTap: _editCurrentPage,
              ),
              _buildPageActionBtn(
                icon: Icons.replay_rounded,
                label: 'Retake',
                onTap: _retakeCurrentPage,
              ),
              _buildPageActionBtn(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: Colors.redAccent,
                onTap: _confirmDeleteCurrentPage,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 4. Horizontal Thumbnail Strip
        SizedBox(
          height: 88,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _pages.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              // Add Page Thumbnail Card
              if (index == _pages.length) {
                return InkWell(
                  onTap: _showAddPageSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 62,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF7046A8).withValues(alpha: 0.5),
                        style: BorderStyle.solid,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF7046A8).withValues(alpha: 0.08),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: Color(0xFF7046A8), size: 26),
                        SizedBox(height: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF7046A8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final isSelected = index == _currentPageIndex;
              final page = _pages[index];

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _currentPageIndex = index;
                  });
                },
                child: Container(
                  width: 62,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF7046A8)
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.file(
                          File(page.processedImagePath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.description),
                        ),
                      ),
                      Positioned(
                        bottom: 3,
                        left: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPageActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final btnColor = color ?? const Color(0xFF7046A8);

    return InkWell(
      onTap: _isProcessing ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: btnColor),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: btnColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1A24) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Add Page Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7046A8),
                side: const BorderSide(color: Color(0xFF7046A8), width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _showAddPageSheet,
              icon: const Icon(Icons.add_a_photo_rounded, size: 18),
              label: const Text(
                'Add Page',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),

            // Prominent "Create PDF" Button
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
                onPressed: _isProcessing ? null : _promptPdfCreation,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                label: Text(
                  'Create PDF (${_pages.length})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
