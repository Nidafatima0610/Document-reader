import 'dart:io';
import 'dart:ui' as ui;
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/document_save_service.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:all_documents_reader/widgets/generated_pdf_success_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';

enum AnnotationToolMode {
  none,
  highlight,
  textBox,
  freehand,
  signature,
}

class _PlacedAnnotation {
  final String id;
  final int pageIndex; // 0-based
  final AnnotationToolMode type;
  Offset position; // normalized 0.0 to 1.0 or pixel coordinates
  Size size;
  String? text;
  Color color;
  List<Offset>? strokePoints;
  ui.Image? signatureImage;
  List<int>? signaturePngBytes;

  _PlacedAnnotation({
    required this.id,
    required this.pageIndex,
    required this.type,
    required this.position,
    this.size = const Size(120, 40),
    this.text,
    this.color = const Color(0xFF7046A8),
    this.strokePoints,
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
  bool _isLoading = false;
  bool _isSaving = false;

  int _currentPageIndex = 0; // 0-based
  AnnotationToolMode _activeTool = AnnotationToolMode.none;
  final Color _selectedColor = const Color(0xFFFFEB3B); // Yellow default for highlight

  final List<_PlacedAnnotation> _annotations = [];
  final List<Offset> _currentStroke = [];
  final GlobalKey<SfSignaturePadState> _signaturePadKey = GlobalKey<SfSignaturePadState>();

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
      _currentPageIndex = 0;
      _annotations.clear();
      _activeTool = AnnotationToolMode.none;
    });

    try {
      final info = await PdfOperationsService.instance.inspectPdf(path);
      setState(() {
        _pdfInfo = info;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Could not read PDF: $e');
    }
  }

  void _onCanvasPanStart(DragStartDetails details, Size canvasSize) {
    if (_activeTool == AnnotationToolMode.freehand) {
      setState(() {
        _currentStroke.clear();
        _currentStroke.add(details.localPosition);
      });
    }
  }

  void _onCanvasPanUpdate(DragUpdateDetails details, Size canvasSize) {
    if (_activeTool == AnnotationToolMode.freehand) {
      setState(() {
        _currentStroke.add(details.localPosition);
      });
    }
  }

  void _onCanvasPanEnd(DragEndDetails details, Size canvasSize) {
    if (_activeTool == AnnotationToolMode.freehand && _currentStroke.isNotEmpty) {
      setState(() {
        _annotations.add(
          _PlacedAnnotation(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            pageIndex: _currentPageIndex,
            type: AnnotationToolMode.freehand,
            position: _currentStroke.first,
            color: _selectedColor == const Color(0xFFFFEB3B) ? const Color(0xFF7046A8) : _selectedColor,
            strokePoints: List<Offset>.from(_currentStroke),
          ),
        );
        _currentStroke.clear();
      });
    }
  }

  void _onCanvasTapUp(TapUpDetails details, Size canvasSize) {
    if (_activeTool == AnnotationToolMode.highlight) {
      // Add standard highlight strip at tapped point
      setState(() {
        _annotations.add(
          _PlacedAnnotation(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            pageIndex: _currentPageIndex,
            type: AnnotationToolMode.highlight,
            position: Offset(20, details.localPosition.dy.clamp(20, canvasSize.height - 30)),
            size: Size(canvasSize.width - 40, 20),
            color: _selectedColor.withValues(alpha: 0.4),
          ),
        );
      });
      _showSnackBar('Highlight bar placed');
    } else if (_activeTool == AnnotationToolMode.textBox) {
      _showAddTextDialog(details.localPosition);
    }
  }

  void _showAddTextDialog(Offset tapPos) {
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
                      position: tapPos,
                      text: text,
                      color: const Color(0xFF7046A8),
                    ),
                  );
                });
                _showSnackBar('Text comment placed');
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
                        position: const Offset(50, 200),
                        size: const Size(140, 70),
                        signatureImage: image,
                        signaturePngBytes: pngBytes,
                      ),
                    );
                  });
                  _showSnackBar('Signature placed! You can reposition it on the page.');
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

  Future<void> _exportAnnotatedPdf() async {
    if (_pdfFile == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final inputBytes = await _pdfFile!.readAsBytes();
      final doc = PdfDocument(inputBytes: inputBytes);

      try {
        for (int pIdx = 0; pIdx < doc.pages.count; pIdx++) {
          final page = doc.pages[pIdx];
          final pageAnns = _annotations.where((a) => a.pageIndex == pIdx).toList();

          for (final ann in pageAnns) {
            switch (ann.type) {
              case AnnotationToolMode.highlight:
                // Draw translucent yellow/color highlight rectangle
                page.graphics.drawRectangle(
                  brush: PdfSolidBrush(PdfColor(255, 235, 59, 90)),
                  bounds: Rect.fromLTWH(ann.position.dx, ann.position.dy, ann.size.width, ann.size.height),
                );
                break;

              case AnnotationToolMode.textBox:
                if (ann.text != null && ann.text!.isNotEmpty) {
                  // White background bubble
                  page.graphics.drawRectangle(
                    brush: PdfSolidBrush(PdfColor(255, 255, 255)),
                    pen: PdfPen(PdfColor(112, 70, 168), width: 1),
                    bounds: Rect.fromLTWH(ann.position.dx, ann.position.dy, 160, 36),
                  );
                  page.graphics.drawString(
                    ann.text!,
                    PdfStandardFont(PdfFontFamily.helvetica, 10),
                    brush: PdfSolidBrush(PdfColor(45, 36, 53)),
                    bounds: Rect.fromLTWH(ann.position.dx + 4, ann.position.dy + 4, 152, 28),
                  );
                }
                break;

              case AnnotationToolMode.freehand:
                if (ann.strokePoints != null && ann.strokePoints!.length > 1) {
                  final pen = PdfPen(
                    PdfColor(ann.color.r.toInt(), ann.color.g.toInt(), ann.color.b.toInt()),
                    width: 2.0,
                  );
                  for (int i = 0; i < ann.strokePoints!.length - 1; i++) {
                    page.graphics.drawLine(
                      pen,
                      ann.strokePoints![i],
                      ann.strokePoints![i + 1],
                    );
                  }
                }
                break;

              case AnnotationToolMode.signature:
                if (ann.signaturePngBytes != null) {
                  final bitmap = PdfBitmap(ann.signaturePngBytes!);
                  page.graphics.drawImage(
                    bitmap,
                    Rect.fromLTWH(ann.position.dx, ann.position.dy, ann.size.width, ann.size.height),
                  );
                }
                break;

              case AnnotationToolMode.none:
                break;
            }
          }
        }

        final pdfBytes = await doc.save();
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
      } finally {
        doc.dispose();
      }
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Annotate & Sign PDF'),
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
              : Column(
                  children: [
                    // Tool Selector Bar
                    _buildToolSelector(isDark, cardBg),

                    // Page Navigation Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                            onPressed: _currentPageIndex > 0
                                ? () => setState(() => _currentPageIndex--)
                                : null,
                          ),
                          Text(
                            'Page ${_currentPageIndex + 1} of ${_pdfInfo?.pageCount ?? 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                            onPressed: (_pdfInfo != null && _currentPageIndex < _pdfInfo!.pageCount - 1)
                                ? () => setState(() => _currentPageIndex++)
                                : null,
                          ),
                        ],
                      ),
                    ),

                    // Interactive Drawing & Markup Canvas
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                            return GestureDetector(
                              onPanStart: (d) => _onCanvasPanStart(d, canvasSize),
                              onPanUpdate: (d) => _onCanvasPanUpdate(d, canvasSize),
                              onPanEnd: (d) => _onCanvasPanEnd(d, canvasSize),
                              onTapUp: (d) => _onCanvasTapUp(d, canvasSize),
                              child: Stack(
                                children: [
                                  // Background placeholder document texture
                                  Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.picture_as_pdf_rounded, size: 48, color: Colors.grey[300]),
                                        const SizedBox(height: 8),
                                        Text(
                                          'PDF Page ${_currentPageIndex + 1}',
                                          style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _activeTool == AnnotationToolMode.highlight
                                              ? 'Tap to place highlight bar'
                                              : _activeTool == AnnotationToolMode.textBox
                                                  ? 'Tap to place text note'
                                                  : _activeTool == AnnotationToolMode.freehand
                                                      ? 'Draw with finger'
                                                      : 'Select a markup tool below',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Placed Annotations Render
                                  ...currentPageAnns.map((ann) {
                                    if (ann.type == AnnotationToolMode.highlight) {
                                      return Positioned(
                                        left: ann.position.dx,
                                        top: ann.position.dy,
                                        width: ann.size.width,
                                        height: ann.size.height,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.yellow.withValues(alpha: 0.4),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      );
                                    } else if (ann.type == AnnotationToolMode.textBox) {
                                      return Positioned(
                                        left: ann.position.dx,
                                        top: ann.position.dy,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(color: const Color(0xFF7046A8)),
                                            borderRadius: BorderRadius.circular(6),
                                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                          ),
                                          child: Text(
                                            ann.text ?? '',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF2D2435), fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      );
                                    } else if (ann.type == AnnotationToolMode.signature && ann.signatureImage != null) {
                                      return Positioned(
                                        left: ann.position.dx,
                                        top: ann.position.dy,
                                        width: ann.size.width,
                                        height: ann.size.height,
                                        child: GestureDetector(
                                          onPanUpdate: (d) {
                                            setState(() {
                                              ann.position += d.delta;
                                            });
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5), width: 1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: RawImage(image: ann.signatureImage, fit: BoxFit.contain),
                                          ),
                                        ),
                                      );
                                    } else if (ann.type == AnnotationToolMode.freehand && ann.strokePoints != null) {
                                      return CustomPaint(
                                        painter: _StrokePainter(points: ann.strokePoints!, color: ann.color),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  }),

                                  // Active drawing stroke
                                  if (_currentStroke.isNotEmpty)
                                    CustomPaint(
                                      painter: _StrokePainter(
                                        points: _currentStroke,
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

                    // Annotations count info
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${currentPageAnns.length} markup item(s) on this page', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
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
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7046A8),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSaving ? null : _exportAnnotatedPdf,
                    icon: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _isSaving ? 'Saving Signed PDF...' : 'Save & Export PDF (${_annotations.length} markups)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            )
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
              child: const Icon(Icons.draw_rounded, size: 48, color: Color(0xFF7046A8)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select PDF to Annotate & Sign',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Highlight text, add notes, draw freehand comments, and place verified handwritten signatures with standard PDF export.',
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
                label: const Text('Select PDF Document', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolSelector(bool isDark, Color cardBg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildToolButton(AnnotationToolMode.none, Icons.pan_tool_rounded, 'Pan / View'),
            const SizedBox(width: 8),
            _buildToolButton(AnnotationToolMode.highlight, Icons.highlight_rounded, 'Highlight'),
            const SizedBox(width: 8),
            _buildToolButton(AnnotationToolMode.textBox, Icons.note_add_rounded, 'Text Note'),
            const SizedBox(width: 8),
            _buildToolButton(AnnotationToolMode.freehand, Icons.edit_rounded, 'Freehand Pen'),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7046A8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: _showSignatureDialog,
              icon: const Icon(Icons.gesture_rounded, size: 16),
              label: const Text('Add Signature'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton(AnnotationToolMode mode, IconData icon, String label) {
    final isSelected = _activeTool == mode;
    return ChoiceChip(
      selected: isSelected,
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF7046A8)),
      label: Text(label),
      selectedColor: const Color(0xFF7046A8),
      onSelected: (_) => setState(() => _activeTool = mode),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;

  _StrokePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}
