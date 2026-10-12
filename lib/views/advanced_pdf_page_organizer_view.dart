import 'dart:io';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:all_documents_reader/widgets/generated_pdf_success_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
  final List<_PageState> _pages = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialPdfPath != null) {
      _loadPdf(widget.initialPdfPath!);
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result.isEmpty || result.first.path == null) return;
      _loadPdf(result.first.path!);
    } catch (e) {
      _showSnackBar('Failed to select PDF: $e');
    }
  }

  Future<void> _loadPdf(String path) async {
    setState(() {
      _isLoading = true;
      _pdfFile = File(path);
      _pages.clear();
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
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Cannot read PDF: $e');
    }
  }

  void _rotatePage(int index) {
    setState(() {
      final cur = _pages[index].rotation;
      _pages[index].rotation = (cur + 90) % 360;
    });
  }

  void _movePage(int from, int to) {
    if (to < 0 || to >= _pages.length) return;
    setState(() {
      final item = _pages.removeAt(from);
      _pages.insert(to, item);
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
        content: Text('Remove Page ${index + 1} (Original ${_pages[index].originalPageNumber}) from the document?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _pages.removeAt(index));
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
    final allSelected = _pages.every((p) => p.isSelected);
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
    if (_pages.isEmpty) return;

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Page Organizer'),
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
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
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
              'Visual page grid: Reorder pages, rotate individual pages, delete unwanted pages, and extract selections into a new PDF.',
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
                label: const Text('Select PDF File', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          '${_pages.length} pages in output • ${_pdfInfo?.formattedSize ?? ''}',
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
                    _pages.every((p) => p.isSelected) ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 16,
                    color: const Color(0xFF7046A8),
                  ),
                  label: Text(_pages.every((p) => p.isSelected) ? 'Deselect' : 'Select All'),
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

        const SizedBox(height: 8),

        // Interactive Page Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.82,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final page = _pages[index];
              final isFirst = index == 0;
              final isLast = index == _pages.length - 1;

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
                    width: page.isSelected ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header: Selection & Delete
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

                      // Center: Visual Page Icon & Labels
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Transform.rotate(
                                angle: page.rotation * (3.141592653589793 / 180),
                                child: Container(
                                  width: 50,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2E2638) : const Color(0xFFF3EFF7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF7046A8).withValues(alpha: 0.4)),
                                  ),
                                  child: const Icon(
                                    Icons.article_rounded,
                                    color: Color(0xFF7046A8),
                                    size: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Page ${index + 1}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                'Orig: ${page.originalPageNumber}',
                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),

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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool isDark, Color cardBg, int selectedCount) {
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
            onPressed: _isProcessing || _pages.isEmpty ? null : _saveOrganizedPdf,
            icon: _isProcessing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            label: Text(
              _isProcessing ? 'Generating PDF...' : 'Export Organized PDF (${_pages.length} pages)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
