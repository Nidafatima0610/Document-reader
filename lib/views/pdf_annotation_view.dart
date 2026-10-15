import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/document_save_service.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:all_documents_reader/widgets/generated_pdf_success_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'package:syncfusion_pdfviewer_platform_interface/pdfviewer_platform_interface.dart';

enum AnnotationToolMode {
  none,
  highlight,
  textBox,
  freehand,
  signature,
}

/// Normalized annotation model (0.0 to 1.0) so coordinates match exactly
/// regardless of screen dimensions, device density, zoom, or PDF page sizes.
class _PlacedAnnotation {
  final String id;
  final int pageIndex; // 0-based
  final AnnotationToolMode type;
  double normX; // 0.0 to 1.0
  double normY; // 0.0 to 1.0
  double normWidth; // 0.0 to 1.0
  double normHeight; // 0.0 to 1.0
  String? text;
  Color color;
  List<Offset>? normStrokePoints; // points in 0.0 to 1.0
  ui.Image? signatureImage;
  List<int>? signaturePngBytes;

  _PlacedAnnotation({
    required this.id,
    required this.pageIndex,
    required this.type,
    required this.normX,
    required this.normY,
    this.normWidth = 0.25,
    this.normHeight = 0.06,
    this.text,
    this.color = const Color(0xFF7046A8),
    this.normStrokePoints,
    this.signatureImage,
    this.signaturePngBytes,
  });
}

class PdfAnnotationView extends StatefulWidget {
  final String? initialPdfPath;

  const PdfAnnotationView({super.key, this.initialPdfPath});

  @override
  State<PdfAnnotationView> createState() => _PdfAnnotationViewState();
}

class _PdfAnnotationViewState extends State<PdfAnnotationView> {
  File? _pdfFile;
  InspectedPdfInfo? _pdfInfo;
  bool _isLoadingPdf = false;
  bool _isSaving = false;

  int _currentPageIndex = 0; // 0-based
  AnnotationToolMode _activeTool = AnnotationToolMode.none;
  final Color _selectedColor = const Color(0xFFFFEB3B); // Yellow default for highlight

  // Real PDF page rendering state
  ui.Image? _currentPageImage;
  bool _isRenderingPage = false;
  String? _pageRenderError;
  String? _activeDocId;

  final List<_PlacedAnnotation> _annotations = [];
  final List<Offset> _currentRawStroke = [];
  final GlobalKey<SfSignaturePadState> _signaturePadKey = GlobalKey<SfSignaturePadState>();

  @override
  void initState() {
    super.initState();
    if (widget.initialPdfPath != null) {
      _loadPdf(widget.initialPdfPath!);
    }
  }

  @override
  void dispose() {
    _cleanupPageRenderer();
    super.dispose();
  }

  void _cleanupPageRenderer() {
    _currentPageImage?.dispose();
    _currentPageImage = null;

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

      if (result.isEmpty || result.first.path == null) return;
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
    _cleanupPageRenderer();

    setState(() {
      _isLoadingPdf = true;
      _pdfFile = File(path);
      _currentPageIndex = 0;
      _annotations.clear();
      _activeTool = AnnotationToolMode.none;
      _pageRenderError = null;
    });

    try {
      final info = await PdfOperationsService.instance.inspectPdf(path);
      final bytes = await _pdfFile!.readAsBytes();

      final docId = 'annotator_${DateTime.now().microsecondsSinceEpoch}';
      _activeDocId = docId;
      await PdfViewerPlatform.instance.initializePdfRenderer(bytes, docId);

      setState(() {
        _pdfInfo = info;
        _isLoadingPdf = false;
      });

      // Render the first page image
      await _renderCurrentPage();
    } catch (e) {
      setState(() {
        _isLoadingPdf = false;
        _pageRenderError = 'Could not load PDF: $e';
      });
      _showSnackBar('Could not read PDF: $e');
    }
  }

  Future<void> _renderCurrentPage() async {
    if (_pdfFile == null || _pdfInfo == null || _activeDocId == null) return;

    setState(() {
      _isRenderingPage = true;
      _pageRenderError = null;
    });

    try {
      final pageNum = _currentPageIndex + 1;
      final pageSize = _pdfInfo!.pageSizes.length > _currentPageIndex
          ? _pdfInfo!.pageSizes[_currentPageIndex]
          : const Size(595, 842);

      // Render at sharp mobile resolution (~800-1200 px wide)
      const targetW = 750;
      final targetH = (targetW * (pageSize.height / pageSize.width)).round().clamp(500, 2000);

      final rawPixels = await PdfViewerPlatform.instance.getPage(
        pageNum,
        targetW,
        targetH,
        _activeDocId!,
      );

      if (rawPixels == null || rawPixels.isEmpty) {
        throw StateError('Failed to rasterize PDF page pixels from native engine.');
      }

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        rawPixels,
        targetW,
        targetH,
        ui.PixelFormat.rgba8888,
        (img) => completer.complete(img),
      );
      final newImage = await completer.future;

      if (!mounted) {
        newImage.dispose();
        return;
      }

      _currentPageImage?.dispose();
      setState(() {
        _currentPageImage = newImage;
        _isRenderingPage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRenderingPage = false;
        _pageRenderError = 'Failed to render PDF page: $e';
      });
    }
  }

  Future<void> _changePage(int newIndex) async {
    if (_pdfInfo == null) return;
    if (newIndex < 0 || newIndex >= _pdfInfo!.pageCount) return;

    setState(() {
      _currentPageIndex = newIndex;
      _currentRawStroke.clear();
    });

    await _renderCurrentPage();
  }

  // --- Coordinate Mapping Helpers ---

  Rect _calculatePageDisplayRect(Size containerSize) {
    if (_pdfInfo == null || _pdfInfo!.pageSizes.isEmpty) {
      return Rect.fromLTWH(0, 0, containerSize.width, containerSize.height);
    }
    final pageIdx = _currentPageIndex.clamp(0, _pdfInfo!.pageSizes.length - 1);
    final srcSize = _pdfInfo!.pageSizes[pageIdx];
    final aspect = srcSize.width / srcSize.height;

    double w = containerSize.width;
    double h = w / aspect;

    if (h > containerSize.height) {
      h = containerSize.height;
      w = h * aspect;
    }

    final left = (containerSize.width - w) / 2;
    final top = (containerSize.height - h) / 2;
    return Rect.fromLTWH(left, top, w, h);
  }

  void _onCanvasPanStart(DragStartDetails details, Rect pageRect) {
    if (_activeTool == AnnotationToolMode.freehand && pageRect.contains(details.localPosition)) {
      setState(() {
        _currentRawStroke.clear();
        _currentRawStroke.add(details.localPosition);
      });
    }
  }

  void _onCanvasPanUpdate(DragUpdateDetails details, Rect pageRect) {
    if (_activeTool == AnnotationToolMode.freehand) {
      setState(() {
        _currentRawStroke.add(details.localPosition);
      });
    }
  }

  void _onCanvasPanEnd(DragEndDetails details, Rect pageRect) {
    if (_activeTool == AnnotationToolMode.freehand && _currentRawStroke.length > 1) {
      final normPoints = _currentRawStroke.map((p) {
        final nx = ((p.dx - pageRect.left) / pageRect.width).clamp(0.0, 1.0);
        final ny = ((p.dy - pageRect.top) / pageRect.height).clamp(0.0, 1.0);
        return Offset(nx, ny);
      }).toList();

      setState(() {
        _annotations.add(
          _PlacedAnnotation(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            pageIndex: _currentPageIndex,
            type: AnnotationToolMode.freehand,
            normX: normPoints.first.dx,
            normY: normPoints.first.dy,
            color: _selectedColor == const Color(0xFFFFEB3B) ? const Color(0xFF7046A8) : _selectedColor,
            normStrokePoints: normPoints,
          ),
        );
        _currentRawStroke.clear();
      });
    }
  }

  void _onCanvasTapUp(TapUpDetails details, Rect pageRect) {
    if (!pageRect.contains(details.localPosition)) return;

    final normX = ((details.localPosition.dx - pageRect.left) / pageRect.width).clamp(0.0, 0.95);
    final normY = ((details.localPosition.dy - pageRect.top) / pageRect.height).clamp(0.0, 0.95);

    if (_activeTool == AnnotationToolMode.highlight) {
      // Add highlight bar across ~80% of line width at tapped Y position
      setState(() {
        _annotations.add(
          _PlacedAnnotation(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            pageIndex: _currentPageIndex,
            type: AnnotationToolMode.highlight,
            normX: 0.1,
            normY: normY.clamp(0.02, 0.96),
            normWidth: 0.8,
            normHeight: 0.025,
            color: _selectedColor.withValues(alpha: 0.4),
          ),
        );
      });
      _showSnackBar('Highlight strip placed');
    } else if (_activeTool == AnnotationToolMode.textBox) {
      _showAddTextDialog(normX, normY);
    }
  }

  void _showAddTextDialog(double normX, double normY) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Text Comment / Note', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter comment text...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7046A8), foregroundColor: Colors.white),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                setState(() {
                  _annotations.add(
                    _PlacedAnnotation(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      pageIndex: _currentPageIndex,
                      type: AnnotationToolMode.textBox,
                      normX: normX,
                      normY: normY,
                      normWidth: 0.35,
                      normHeight: 0.07,
                      text: text,
                      color: const Color(0xFF7046A8),
                    ),
                  );
                });
                _showSnackBar('Comment placed');
              }
            },
            child: const Text('Place Note'),
          ),
        ],
      ),
    );
  }

  void _showSignatureDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Draw Signature', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => _signaturePadKey.currentState?.clear(),
                  child: const Text('Clear Canvas'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF7046A8), width: 1.5),
              ),
              child: SfSignaturePad(
                key: _signaturePadKey,
                backgroundColor: Colors.white,
                strokeColor: const Color(0xFF1A1A24),
                minimumStrokeWidth: 2.0,
                maximumStrokeWidth: 4.0,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7046A8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () async {
                try {
                  final ui.Image image = await _signaturePadKey.currentState!.toImage();
                  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                  final pngBytes = byteData!.buffer.asUint8List();

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  if (!mounted) return;
                  setState(() {
                    _annotations.add(
                      _PlacedAnnotation(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        pageIndex: _currentPageIndex,
                        type: AnnotationToolMode.signature,
                        normX: 0.35,
                        normY: 0.75,
                        normWidth: 0.30,
                        normHeight: 0.12,
                        signatureImage: image,
                        signaturePngBytes: pngBytes,
                      ),
                    );
                  });
                  _showSnackBar('Signature placed! Drag to reposition.');
                } catch (e) {
                  _showSnackBar('Could not capture signature: $e');
                }
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Apply Signature to Page', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<int>> _generateAnnotatedPdfBytes() async {
    if (_pdfFile == null) throw StateError('No PDF loaded');
    final inputBytes = await _pdfFile!.readAsBytes();
    final doc = PdfDocument(inputBytes: inputBytes);

    try {
      for (int pIdx = 0; pIdx < doc.pages.count; pIdx++) {
        final page = doc.pages[pIdx];
        final pageSize = page.size;
        final pageAnns = _annotations.where((a) => a.pageIndex == pIdx).toList();

        for (final ann in pageAnns) {
          final pdfX = ann.normX * pageSize.width;
          final pdfY = ann.normY * pageSize.height;
          final pdfW = ann.normWidth * pageSize.width;
          final pdfH = ann.normHeight * pageSize.height;

          switch (ann.type) {
            case AnnotationToolMode.highlight:
              // Draw translucent yellow/color highlight rectangle
              page.graphics.drawRectangle(
                brush: PdfSolidBrush(PdfColor(255, 235, 59, 90)),
                bounds: Rect.fromLTWH(pdfX, pdfY, pdfW, pdfH),
              );
              break;

            case AnnotationToolMode.textBox:
              if (ann.text != null && ann.text!.isNotEmpty) {
                // White background bubble with border
                final bubbleW = pdfW.clamp(120.0, pageSize.width - pdfX);
                final bubbleH = pdfH.clamp(28.0, 100.0);
                page.graphics.drawRectangle(
                  brush: PdfSolidBrush(PdfColor(255, 255, 255)),
                  pen: PdfPen(PdfColor(112, 70, 168), width: 1),
                  bounds: Rect.fromLTWH(pdfX, pdfY, bubbleW, bubbleH),
                );
                page.graphics.drawString(
                  ann.text!,
                  PdfStandardFont(PdfFontFamily.helvetica, 10),
                  brush: PdfSolidBrush(PdfColor(45, 36, 53)),
                  bounds: Rect.fromLTWH(pdfX + 4, pdfY + 4, bubbleW - 8, bubbleH - 8),
                  format: PdfStringFormat(lineSpacing: 2),
                );
              }
              break;

            case AnnotationToolMode.freehand:
              if (ann.normStrokePoints != null && ann.normStrokePoints!.length > 1) {
                final pen = PdfPen(
                  PdfColor(ann.color.r.toInt(), ann.color.g.toInt(), ann.color.b.toInt()),
                  width: 2.5,
                );
                for (int i = 0; i < ann.normStrokePoints!.length - 1; i++) {
                  final p1 = ann.normStrokePoints![i];
                  final p2 = ann.normStrokePoints![i + 1];
                  page.graphics.drawLine(
                    pen,
                    Offset(p1.dx * pageSize.width, p1.dy * pageSize.height),
                    Offset(p2.dx * pageSize.width, p2.dy * pageSize.height),
                  );
                }
              }
              break;

            case AnnotationToolMode.signature:
              if (ann.signaturePngBytes != null) {
                final bitmap = PdfBitmap(ann.signaturePngBytes!);
                page.graphics.drawImage(
                  bitmap,
                  Rect.fromLTWH(pdfX, pdfY, pdfW, pdfH),
                );
              }
              break;

            case AnnotationToolMode.none:
              break;
          }
        }
      }

      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  Future<void> _previewAnnotatedPdf() async {
    if (_pdfFile == null) return;
    try {
      final bytes = await _generateAnnotatedPdfBytes();
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              AppBar(
                title: const Text('Annotated PDF Preview'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Expanded(
                child: SfPdfViewer.memory(Uint8List.fromList(bytes)),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7046A8),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _exportAnnotatedPdf();
                      },
                      icon: const Icon(Icons.save_alt_rounded),
                      label: const Text('Save Annotated PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _showSnackBar('Preview generation failed: $e');
    }
  }

  Future<void> _exportAnnotatedPdf() async {
    if (_pdfFile == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final pdfBytes = await _generateAnnotatedPdfBytes();
      final saveDir = await DocumentsStorageService.instance.getAppDocumentsDirectory();
      final base = _pdfInfo?.fileName ?? 'Annotated.pdf';
      final cleanBase = base.replaceAll('.pdf', '_signed.pdf');
      final uniqueName = DocumentSaveService.instance.generateUniqueFileName(
        directory: saveDir,
        baseName: cleanBase,
      );

      final newFile = File('${saveDir.path}/$uniqueName');
      await newFile.writeAsBytes(pdfBytes, flush: true);

      final newDoc = DocumentsModel(
        name: uniqueName,
        path: newFile.path,
        type: 'pdf',
        createdAt: DateTime.now(),
      );
      await DocumentsStorageService.instance.addDocument(newDoc);

      setState(() => _isSaving = false);
      if (!mounted) return;

      GeneratedPdfSuccessSheet.show(
        context: context,
        document: newDoc,
        file: newFile,
        subtitle: '${_pdfInfo?.pageCount ?? 1} pages • ${(pdfBytes.length / 1024).toStringAsFixed(1)} KB',
        onDone: () => Navigator.pop(context),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Failed to export annotated PDF: $e');
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

    final currentPageAnns = _annotations.where((a) => a.pageIndex == _currentPageIndex).toList();

    return PopScope(
      canPop: _annotations.isEmpty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Discard Unsaved Markups?'),
            content: Text('You have ${_annotations.length} markup(s) on this PDF. Leaving now will discard them.'),
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
              Text('Annotate & Sign PDF', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              Text('Draw, highlight, comment & sign pages', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          actions: [
            if (_pdfFile != null && !_isLoadingPdf) ...[
              IconButton(
                icon: const Icon(Icons.visibility_outlined),
                tooltip: 'Preview PDF',
                onPressed: _previewAnnotatedPdf,
              ),
              IconButton(
                icon: const Icon(Icons.file_upload_outlined),
                tooltip: 'Change PDF',
                onPressed: _pickPdf,
              ),
            ],
          ],
        ),
      body: _isLoadingPdf
          ? const Center(child: CircularProgressIndicator())
          : _pdfFile == null
              ? _buildEmptyState(isDark)
              : Column(
                  children: [
                    // Tool Selector Bar
                    _buildToolSelector(isDark, cardBg),

                    // Page Navigation Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                            onPressed: _currentPageIndex > 0
                                ? () => _changePage(_currentPageIndex - 1)
                                : null,
                          ),
                          Text(
                            'Page ${_currentPageIndex + 1} of ${_pdfInfo?.pageCount ?? 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                            onPressed: (_pdfInfo != null && _currentPageIndex < _pdfInfo!.pageCount - 1)
                                ? () => _changePage(_currentPageIndex + 1)
                                : null,
                          ),
                        ],
                      ),
                    ),

                    // Interactive Drawing & Markup Canvas with Real PDF Render
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1B1722) : const Color(0xFFF0EDF5),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
                            final pageRect = _calculatePageDisplayRect(containerSize);

                            if (_isRenderingPage) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const CircularProgressIndicator(color: Color(0xFF7046A8)),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Rendering Page ${_currentPageIndex + 1}...',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              );
                            }

                            if (_pageRenderError != null) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
                                      const SizedBox(height: 10),
                                      Text(
                                        _pageRenderError!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12, color: Colors.red),
                                      ),
                                      const SizedBox(height: 14),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7046A8), foregroundColor: Colors.white),
                                        onPressed: _renderCurrentPage,
                                        icon: const Icon(Icons.refresh_rounded),
                                        label: const Text('Retry Rendering'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return GestureDetector(
                              onPanStart: (d) => _onCanvasPanStart(d, pageRect),
                              onPanUpdate: (d) => _onCanvasPanUpdate(d, pageRect),
                              onPanEnd: (d) => _onCanvasPanEnd(d, pageRect),
                              onTapUp: (d) => _onCanvasTapUp(d, pageRect),
                              child: Stack(
                                children: [
                                  // 1. Real PDF Page Image Rasterized Underneath
                                  Positioned(
                                    left: pageRect.left,
                                    top: pageRect.top,
                                    width: pageRect.width,
                                    height: pageRect.height,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                                        ],
                                      ),
                                      child: _currentPageImage != null
                                          ? RawImage(
                                              image: _currentPageImage,
                                              fit: BoxFit.fill,
                                            )
                                          : const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                    ),
                                  ),

                                  // 2. Placed Annotations Render (proportional to pageRect)
                                  ...currentPageAnns.map((ann) {
                                    final itemX = pageRect.left + (ann.normX * pageRect.width);
                                    final itemY = pageRect.top + (ann.normY * pageRect.height);
                                    final itemW = ann.normWidth * pageRect.width;
                                    final itemH = ann.normHeight * pageRect.height;

                                    if (ann.type == AnnotationToolMode.highlight) {
                                      return Positioned(
                                        left: itemX,
                                        top: itemY,
                                        width: itemW,
                                        height: itemH,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.yellow.withValues(alpha: 0.45),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      );
                                    } else if (ann.type == AnnotationToolMode.textBox) {
                                      final boxW = itemW.clamp(120.0, pageRect.width - (itemX - pageRect.left));
                                      return Positioned(
                                        left: itemX,
                                        top: itemY,
                                        width: boxW,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                border: Border.all(color: const Color(0xFF7046A8), width: 1.2),
                                                borderRadius: BorderRadius.circular(6),
                                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                              ),
                                              child: Text(
                                                ann.text ?? '',
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF2D2435), fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                            Positioned(
                                              top: -6,
                                              right: -6,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _annotations.remove(ann);
                                                  });
                                                  _showSnackBar('Note removed');
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: const BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    } else if (ann.type == AnnotationToolMode.signature && ann.signatureImage != null) {
                                      return Positioned(
                                        left: itemX,
                                        top: itemY,
                                        width: itemW,
                                        height: itemH,
                                        child: GestureDetector(
                                          onPanUpdate: (d) {
                                            setState(() {
                                              ann.normX = ((ann.normX * pageRect.width + d.delta.dx) / pageRect.width).clamp(0.0, 0.95);
                                              ann.normY = ((ann.normY * pageRect.height + d.delta.dy) / pageRect.height).clamp(0.0, 0.95);
                                            });
                                          },
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: const Color(0xFF7046A8), width: 1.5),
                                                  color: const Color(0xFF7046A8).withValues(alpha: 0.05),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: RawImage(image: ann.signatureImage, fit: BoxFit.contain),
                                              ),
                                              Positioned(
                                                top: 2,
                                                left: 2,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF7046A8),
                                                    borderRadius: BorderRadius.circular(3),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.open_with_rounded, size: 9, color: Colors.white),
                                                      SizedBox(width: 2),
                                                      Text('Drag', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                top: -6,
                                                right: -6,
                                                child: GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _annotations.remove(ann);
                                                    });
                                                    _showSnackBar('Signature removed');
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.all(2),
                                                    decoration: const BoxDecoration(
                                                      color: Colors.red,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    } else if (ann.type == AnnotationToolMode.freehand && ann.normStrokePoints != null) {
                                      final screenPoints = ann.normStrokePoints!.map((p) {
                                        return Offset(
                                          pageRect.left + (p.dx * pageRect.width),
                                          pageRect.top + (p.dy * pageRect.height),
                                        );
                                      }).toList();

                                      return CustomPaint(
                                        painter: _StrokePainter(points: screenPoints, color: ann.color),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  }),

                                  // 3. Active in-progress finger stroke
                                  if (_currentRawStroke.isNotEmpty)
                                    CustomPaint(
                                      painter: _StrokePainter(
                                        points: _currentRawStroke,
                                        color: _selectedColor == const Color(0xFFFFEB3B) ? const Color(0xFF7046A8) : _selectedColor,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Annotations count info & page clear
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${currentPageAnns.length} markups on page ${_currentPageIndex + 1}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          if (currentPageAnns.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _annotations.removeWhere((a) => a.pageIndex == _currentPageIndex);
                                });
                              },
                              child: const Text('Clear Page Markups', style: TextStyle(fontSize: 11, color: Colors.red)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _pdfFile != null
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06), blurRadius: 8, offset: const Offset(0, -2)),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF7046A8),
                            side: const BorderSide(color: Color(0xFF7046A8)),
                          ),
                          onPressed: _previewAnnotatedPdf,
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('Preview', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7046A8),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _isSaving ? null : _exportAnnotatedPdf,
                          icon: _isSaving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_rounded, size: 18),
                          label: Text(
                            _isSaving ? 'Saving...' : 'Save Annotated PDF',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
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
              child: const Icon(Icons.draw_rounded, size: 48, color: Color(0xFF7046A8)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select PDF to Annotate & Sign',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Renders actual pages directly on device. Highlight text passages, place floating comments, draw freehand marks, and place handwritten signatures.',
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

  Widget _buildToolSelector(bool isDark, Color cardBg) {
    final tools = [
      {'mode': AnnotationToolMode.none, 'label': 'View', 'icon': Icons.pan_tool_outlined},
      {'mode': AnnotationToolMode.highlight, 'label': 'Highlight', 'icon': Icons.highlight_rounded},
      {'mode': AnnotationToolMode.textBox, 'label': 'Note', 'icon': Icons.note_add_outlined},
      {'mode': AnnotationToolMode.freehand, 'label': 'Draw', 'icon': Icons.gesture_rounded},
      {'mode': AnnotationToolMode.signature, 'label': 'Signature', 'icon': Icons.draw_rounded},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: cardBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: tools.map((t) {
          final mode = t['mode'] as AnnotationToolMode;
          final isSelected = _activeTool == mode;

          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              if (mode == AnnotationToolMode.signature) {
                _showSignatureDialog();
              } else {
                setState(() => _activeTool = mode);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF7046A8).withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? const Color(0xFF7046A8) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    t['icon'] as IconData,
                    size: 20,
                    color: isSelected ? const Color(0xFF7046A8) : Colors.grey,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    t['label'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF7046A8) : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;

  _StrokePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}
