import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:all_documents_reader/widgets/generated_pdf_success_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_pdfviewer_platform_interface/pdfviewer_platform_interface.dart';

class _PageState {
  final int originalPageNumber;
  int rotation = 0; // 0, 90, 180, 270
  bool isSelected = false;

  _PageState({required this.originalPageNumber});
}

class AdvancedPdfPageOrganizerView extends StatefulWidget {
  final String? initialPdfPath;

  const AdvancedPdfPageOrganizerView({super.key, this.initialPdfPath});

  @override
  State<AdvancedPdfPageOrganizerView> createState() => _AdvancedPdfPageOrganizerViewState();
}

class _AdvancedPdfPageOrganizerViewState extends State<AdvancedPdfPageOrganizerView> {
  File? _pdfFile;
  InspectedPdfInfo? _pdfInfo;
  bool _isLoading = false;
  bool _isProcessing = false;
  bool _hasModifications = false;
  final List<_PageState> _pages = [];

  // Thumbnail rendering cache
  final Map<int, ui.Image> _thumbnailImages = {};
  String? _activeDocId;

  @override
  void initState() {
    super.initState();
    if (widget.initialPdfPath != null) {
      _loadPdf(widget.initialPdfPath!);
    }
  }

  @override
  void dispose() {
    _cleanupThumbnails();
    super.dispose();
  }

  void _cleanupThumbnails() {
    for (final img in _thumbnailImages.values) {
      img.dispose();
    }
    _thumbnailImages.clear();

    if (_activeDocId != null) {
      try {
        PdfViewerPlatform.instance.closeDocument(_activeDocId!);
      } catch (_) {}
      _activeDocId = null;
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result.isEmpty || result.first.path == null) {
        // User cancelled picker gracefully
        return;
      }

      final path = result.first.path!;
      final file = File(path);
      if (!file.existsSync() || file.lengthSync() == 0) {
        _showSnackBar('Selected file does not exist or is empty.');
        return;
      }

      if (!path.toLowerCase().endsWith('.pdf')) {
        _showSnackBar('Please select a valid PDF file (.pdf).');
        return;
      }

      _loadPdf(path);
    } catch (e) {
      _showSnackBar('Failed to select PDF: $e');
    }
  }

  Future<void> _loadPdf(String path) async {
    _cleanupThumbnails();

    setState(() {
      _isLoading = true;
      _pdfFile = File(path);
      _pages.clear();
      _hasModifications = false;
    });

    try {
      final info = await PdfOperationsService.instance.inspectPdf(path);
      final list = <_PageState>[];
      for (int i = 1; i <= info.pageCount; i++) {
        list.add(_PageState(originalPageNumber: i));
      }

      setState(() {
        _pdfInfo = info;
        _pages.addAll(list);
        _isLoading = false;
      });

      // Asynchronously render real page thumbnails in background
      _generateThumbnails(path, info.pageCount);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Cannot read PDF. File may be corrupted: $e');
    }
  }

  Future<void> _generateThumbnails(String path, int totalPages) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return;
      final bytes = await file.readAsBytes();
      final docId = 'organizer_${DateTime.now().microsecondsSinceEpoch}';
      _activeDocId = docId;

      await PdfViewerPlatform.instance.initializePdfRenderer(bytes, docId);

      // Render thumbnails for each page (max 50 to conserve memory)
      final pagesToRender = totalPages.clamp(1, 50);
      const targetW = 140;
      const targetH = 190;

      for (int p = 1; p <= pagesToRender; p++) {
        if (!mounted || _activeDocId != docId) break;

        final rawPixels = await PdfViewerPlatform.instance.getPage(p, targetW, targetH, docId);
        if (rawPixels != null && rawPixels.isNotEmpty) {
          final completer = Completer<ui.Image>();
          ui.decodeImageFromPixels(
            rawPixels,
            targetW,
            targetH,
            ui.PixelFormat.rgba8888,
            (img) => completer.complete(img),
          );
          final image = await completer.future;

          if (mounted && _activeDocId == docId) {
            setState(() {
              _thumbnailImages[p] = image;
            });
          } else {
            image.dispose();
          }
        }
      }
    } catch (e) {
      debugPrint('[AdvancedPdfPageOrganizerView] Thumbnail generation note: $e');
    }
  }

  void _rotatePage(int index) {
    setState(() {
      final cur = _pages[index].rotation;
      _pages[index].rotation = (cur + 90) % 360;
      _hasModifications = true;
    });
  }

  void _movePage(int from, int to) {
    if (to < 0 || to >= _pages.length) return;
    setState(() {
      final item = _pages.removeAt(from);
      _pages.insert(to, item);
      _hasModifications = true;
    });
  }

  void _deletePage(int index) {
    if (_pages.length <= 1) {
      _showSnackBar('A document must have at least 1 page.');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Page?'),
        content: Text('Remove Page ${index + 1} (Original Page ${_pages[index].originalPageNumber}) from the document?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _pages.removeAt(index);
                _hasModifications = true;
              });
              _showSnackBar('Page removed.');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- Batch Operations ---

  void _toggleSelectAll() {
    final allSelected = _pages.isNotEmpty && _pages.every((p) => p.isSelected);
    setState(() {
      for (final p in _pages) {
        p.isSelected = !allSelected;
      }
    });
  }

  void _rotateSelected() {
    final count = _pages.where((p) => p.isSelected).length;
    if (count == 0) {
      _showSnackBar('Select one or more pages to rotate.');
      return;
    }
    setState(() {
      for (final p in _pages) {
        if (p.isSelected) {
          p.rotation = (p.rotation + 90) % 360;
        }
      }
    });
    _showSnackBar('Rotated $count selected pages.');
  }

  void _deleteSelected() {
    final selectedCount = _pages.where((p) => p.isSelected).length;
    if (selectedCount == 0) {
      _showSnackBar('No pages selected to delete.');
      return;
    }
    if (selectedCount >= _pages.length) {
      _showSnackBar('Cannot delete all pages. At least 1 page must remain.');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Pages?'),
        content: Text('Permanently remove $selectedCount selected pages from the output document?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _pages.removeWhere((p) => p.isSelected);
              });
              _showSnackBar('Removed $selectedCount pages.');
            },
            child: const Text('Delete Selected'),
          ),
        ],
      ),
    );
  }

  Future<void> _extractSelectedToNewPdf() async {
    final selected = _pages.where((p) => p.isSelected).toList();
    if (selected.isEmpty) {
      _showSnackBar('Select at least 1 page to extract.');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final specs = selected.map((p) => OrganizedPageSpec(
        originalPageNumber: p.originalPageNumber,
        rotationAngle: p.rotation,
      )).toList();

      final result = await PdfOperationsService.instance.organizePdfPages(
        pdfPath: _pdfFile!.path,
        pages: specs,
        customFileName: 'Extracted_${selected.length}_pages.pdf',
      );

      final doc = DocumentsModel(
        name: result.fileName,
        path: result.file.path,
        type: 'pdf',
        createdAt: DateTime.now(),
      );
      await DocumentsStorageService.instance.addDocument(doc);

      setState(() => _isProcessing = false);
      if (!mounted) return;

      GeneratedPdfSuccessSheet.show(
        context: context,
        document: doc,
        file: result.file,
        subtitle: '${result.pageCount} extracted pages • ${result.formattedSize}',
        onDone: () {},
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnackBar('Extraction failed: $e');
    }
  }

  Future<void> _saveOrganizedPdf() async {
    if (_pages.isEmpty) {
      _showSnackBar('No pages left to export. Document must have at least 1 page.');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final specs = _pages.map((p) => OrganizedPageSpec(
        originalPageNumber: p.originalPageNumber,
        rotationAngle: p.rotation,
      )).toList();

      final result = await PdfOperationsService.instance.organizePdfPages(
        pdfPath: _pdfFile!.path,
        pages: specs,
      );

      final doc = DocumentsModel(
        name: result.fileName,
        path: result.file.path,
        type: 'pdf',
        createdAt: DateTime.now(),
      );
      await DocumentsStorageService.instance.addDocument(doc);

      setState(() => _isProcessing = false);
      if (!mounted) return;

      GeneratedPdfSuccessSheet.show(
        context: context,
        document: doc,
        file: result.file,
        subtitle: '${result.pageCount} pages • ${result.formattedSize}',
        onDone: () => Navigator.pop(context),
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnackBar('Failed to save organized PDF: $e');
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF211C29) : Colors.white;
    final selectedCount = _pages.where((p) => p.isSelected).length;

    return PopScope(
      canPop: !_hasModifications,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Discard Page Changes?'),
            content: const Text('You have modified page order or rotations. Leaving now will discard your changes.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Editing')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (discard == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Page Organizer', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              Text('Reorder, rotate, delete & extract pages', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          actions: [
            if (_pdfFile != null && !_isLoading)
              IconButton(
                icon: const Icon(Icons.file_upload_outlined),
                tooltip: 'Change PDF',
                onPressed: _pickPdf,
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _pdfFile == null
                ? _buildEmptyState(isDark)
                : _buildOrganizerGrid(isDark, cardBg, selectedCount),
        bottomNavigationBar: _pdfFile != null
            ? _buildBottomBar(isDark, cardBg, selectedCount)
            : null,
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF7046A8).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.dashboard_customize_rounded, size: 48, color: Color(0xFF7046A8)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select PDF to Organize',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'View visual page thumbnails, reorder page sequence, rotate individual pages (90°, 180°, 270°), delete unwanted pages, and extract selections.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7046A8),
                  foregroundColor: Colors.white,
                ),
                onPressed: _pickPdf,
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Select PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizerGrid(bool isDark, Color cardBg, int selectedCount) {
    return Column(
      children: [
        // File Overview Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Card(
            color: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pdfInfo?.fileName ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${_pages.length} pages in document • $selectedCount selected • ${_pdfInfo?.formattedSize ?? ''}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _pickPdf,
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Batch Action Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: Icon(
                    _pages.isNotEmpty && _pages.every((p) => p.isSelected)
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 16,
                    color: const Color(0xFF7046A8),
                  ),
                  label: Text(_pages.isNotEmpty && _pages.every((p) => p.isSelected) ? 'Deselect All' : 'Select All'),
                  onPressed: _toggleSelectAll,
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.rotate_right_rounded, size: 16, color: Color(0xFF7046A8)),
                  label: Text('Rotate Selected ($selectedCount)'),
                  onPressed: selectedCount > 0 ? _rotateSelected : null,
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                  label: Text('Delete Selected ($selectedCount)', style: const TextStyle(color: Colors.red)),
                  onPressed: selectedCount > 0 ? _deleteSelected : null,
                ),
                if (selectedCount > 0) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.call_split_rounded, size: 16, color: Color(0xFF7046A8)),
                    label: Text('Extract $selectedCount Pages'),
                    onPressed: _extractSelectedToNewPdf,
                  ),
                ],
              ],
            ),
          ),
        ),

        // Guidance banner explaining how to select and manipulate pages
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF7046A8).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF7046A8).withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.touch_app_rounded, size: 16, color: Color(0xFF7046A8)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap any page thumbnail to select/deselect. Use arrows to reorder, rotate button to turn 90°, or remove unwanted pages.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF7046A8)),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Interactive Page Grid
        Expanded(
          child: _pages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.amber),
                        const SizedBox(height: 12),
                        const Text(
                          'All Pages Removed',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'To export, please re-load or add pages back.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            if (_pdfFile != null) _loadPdf(_pdfFile!.path);
                          },
                          child: const Text('Reset All Pages'),
                        ),
                      ],
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    final isFirst = index == 0;
                    final isLast = index == _pages.length - 1;
                    final thumbImg = _thumbnailImages[page.originalPageNumber];

                    return Card(
                      color: page.isSelected
                          ? const Color(0xFF7046A8).withValues(alpha: isDark ? 0.25 : 0.08)
                          : cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: page.isSelected
                              ? const Color(0xFF7046A8)
                              : (isDark ? Colors.white12 : Colors.black12),
                          width: page.isSelected ? 2.5 : 1,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => page.isSelected = !page.isSelected),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                            // Header: Selection Checkbox & Rotation Badge & Delete
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Checkbox(
                                  value: page.isSelected,
                                  activeColor: const Color(0xFF7046A8),
                                  onChanged: (val) {
                                    setState(() => page.isSelected = val ?? false);
                                  },
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7046A8).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${page.rotation}°',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7046A8),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                                  tooltip: 'Remove',
                                  onPressed: () => _deletePage(index),
                                ),
                              ],
                            ),

                            // Center: Visual Thumbnail Preview or Document Badge
                            Expanded(
                              child: Center(
                                child: Transform.rotate(
                                  angle: page.rotation * (3.141592653589793 / 180),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFF7046A8).withValues(alpha: 0.25),
                                        width: 1,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(5),
                                      child: thumbImg != null
                                          ? RawImage(
                                              image: thumbImg,
                                              fit: BoxFit.contain,
                                            )
                                          : Container(
                                              width: 70,
                                              height: 90,
                                              color: isDark ? const Color(0xFF2E2638) : const Color(0xFFF3EFF7),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.article_rounded,
                                                    color: Color(0xFF7046A8),
                                                    size: 28,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'P.${page.originalPageNumber}',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF7046A8),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 4),

                            // Page Labels
                            Text(
                              'Page ${index + 1}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Text(
                              'Orig: Page ${page.originalPageNumber}',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            ),

                            const SizedBox(height: 4),

                            // Footer: Move & Rotate Controls
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                                  tooltip: 'Move Left',
                                  onPressed: isFirst ? null : () => _movePage(index, index - 1),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.rotate_right_rounded, size: 20, color: Color(0xFF7046A8)),
                                  tooltip: 'Rotate +90°',
                                  onPressed: () => _rotatePage(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                                  tooltip: 'Move Right',
                                  onPressed: isLast ? null : () => _movePage(index, index + 1),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool isDark, Color cardBg, int selectedCount) {
    final canExport = !_isProcessing && _pages.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7046A8),
              foregroundColor: Colors.white,
            ),
            onPressed: canExport ? _saveOrganizedPdf : null,
            icon: _isProcessing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            label: Text(
              _pages.isEmpty
                  ? 'No pages to export'
                  : _isProcessing
                      ? 'Saving PDF...'
                      : 'Save Organized PDF (${_pages.length} pages)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
