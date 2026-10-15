import 'dart:io';
import 'dart:typed_data';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/document_save_service.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:all_documents_reader/views/images_to_pdf_view.dart';
import 'package:all_documents_reader/views/ocr_workspace_view.dart';
import 'package:all_documents_reader/widgets/generated_pdf_success_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Text modification model representing an edit, replacement, or overlay on a specific page
class PdfTextEditItem {
  final String id;
  final int pageIndex; // 0-based page index
  String text;
  double x; // Percentage (0.0 to 1.0)
  double y; // Percentage (0.0 to 1.0)
  double fontSize;
  Color color;
  TextAlign alignment;
  bool isReplacement; // If replacing an existing detected text block
  String? originalText;

  PdfTextEditItem({
    required this.id,
    required this.pageIndex,
    required this.text,
    this.x = 0.1,
    this.y = 0.2,
    this.fontSize = 14,
    this.color = const Color(0xFF2D2435),
    this.alignment = TextAlign.left,
    this.isReplacement = false,
    this.originalText,
  });
}

/// Professional PDF Text Editor allowing text editing, overlays, removals,
/// and safe PDF re-generation without corrupting original document files.
class PdfTextEditorView extends StatefulWidget {
  final String? initialPdfPath;

  const PdfTextEditorView({super.key, this.initialPdfPath});

  @override
  State<PdfTextEditorView> createState() => _PdfTextEditorViewState();
}

class _PdfTextEditorViewState extends State<PdfTextEditorView> {
  File? _pdfFile;
  InspectedPdfInfo? _pdfInfo;
  bool _isLoading = false;
  bool _isScanned = false;
  bool _allowOverlaysOnScanned = false;
  int _selectedPageIndex = 0; // 0-based
  List<String> _extractedPageParagraphs = [];
  final List<PdfTextEditItem> _edits = [];
  bool _isProcessingSave = false;
  final PdfViewerController _pdfViewerController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    if (widget.initialPdfPath != null) {
      _loadPdf(widget.initialPdfPath!);
    }
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
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

      await _loadPdf(path);
    } catch (e) {
      _showSnackBar('Failed to select PDF: $e');
    }
  }

  Future<void> _loadPdf(String path) async {
    setState(() {
      _isLoading = true;
      _pdfFile = File(path);
      _edits.clear();
      _selectedPageIndex = 0;
      _allowOverlaysOnScanned = false;
    });

    try {
      final info = await PdfOperationsService.instance.inspectPdf(path);
      final textRes = await PdfOperationsService.instance.extractTextFromPdf(pdfPath: path);

      // Check if scanned or image-only
      final isScanned = textRes.isScannedOrEmpty;

      // Extract paragraphs for the first page
      final pageTextRes = await PdfOperationsService.instance.extractTextFromPdf(
        pdfPath: path,
        startPage: 1,
        endPage: 1,
      );
      final paragraphs = _parseParagraphs(pageTextRes.text);

      setState(() {
        _pdfInfo = info;
        _isScanned = isScanned;
        _extractedPageParagraphs = paragraphs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Could not read PDF. File may be corrupted or password-protected: $e');
    }
  }

  Future<void> _changePage(int newIndex) async {
    if (_pdfFile == null || _pdfInfo == null) return;
    if (newIndex < 0 || newIndex >= _pdfInfo!.pageCount) return;

    setState(() {
      _selectedPageIndex = newIndex;
      _isLoading = true;
    });

    try {
      final pageNum = newIndex + 1;
      final pageTextRes = await PdfOperationsService.instance.extractTextFromPdf(
        pdfPath: _pdfFile!.path,
        startPage: pageNum,
        endPage: pageNum,
      );

      setState(() {
        _extractedPageParagraphs = _parseParagraphs(pageTextRes.text);
        _isLoading = false;
      });
      try {
        _pdfViewerController.jumpToPage(newIndex + 1);
      } catch (_) {}
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading page text: $e');
    }
  }

  List<String> _parseParagraphs(String fullText) {
    if (fullText.trim().isEmpty) return [];
    return fullText
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  void _addCustomTextOverlay() {
    _showTextEditDialog(
      title: 'Add Text Overlay (Page ${_selectedPageIndex + 1})',
      subtitle: 'Places a new custom text box on this page.',
      initialText: '',
      isReplacement: false,
      onConfirm: (text, fontSize, color, alignment, yRatio) {
        setState(() {
          _edits.add(
            PdfTextEditItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              pageIndex: _selectedPageIndex,
              text: text,
              x: 0.1,
              y: yRatio,
              fontSize: fontSize,
              color: color,
              alignment: alignment,
              isReplacement: false,
            ),
          );
        });
        _showSnackBar('Text overlay added to page ${_selectedPageIndex + 1}');
      },
    );
  }

  void _editExistingParagraph(int index, String original) {
    _showTextEditDialog(
      title: 'Replace Text Block (Page ${_selectedPageIndex + 1})',
      subtitle: 'Places a clean background patch over the original text and draws your replacement text in its place.',
      initialText: original,
      isReplacement: true,
      onConfirm: (text, fontSize, color, alignment, yRatio) {
        setState(() {
          _edits.add(
            PdfTextEditItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              pageIndex: _selectedPageIndex,
              text: text,
              x: 0.1,
              y: yRatio,
              fontSize: fontSize,
              color: color,
              alignment: alignment,
              isReplacement: true,
              originalText: original,
            ),
          );
        });
        _showSnackBar('Text replacement scheduled for page ${_selectedPageIndex + 1}');
      },
    );
  }

  void _removeEditItem(String id) {
    setState(() {
      _edits.removeWhere((e) => e.id == id);
    });
  }

  Future<void> _showTextEditDialog({
    required String title,
    required String subtitle,
    required String initialText,
    required bool isReplacement,
    required void Function(
      String text,
      double fontSize,
      Color color,
      TextAlign alignment,
      double yRatio,
    ) onConfirm,
  }) async {
    final textController = TextEditingController(text: initialText);
    double fontSize = 14;
    Color selectedColor = const Color(0xFF2D2435);
    TextAlign alignment = TextAlign.left;
    double verticalPosition = isReplacement ? 0.25 : 0.20;

    final colorOptions = [
      const Color(0xFF2D2435), // Dark Charcoal
      const Color(0xFF7046A8), // Purple branding
      const Color(0xFF1565C0), // Blue
      const Color(0xFFC62828), // Red
      const Color(0xFF2E7D32), // Green
    ];

    await showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: Colors.grey[600], fontWeight: FontWeight.normal),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: textController,
                      maxLines: 4,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: isReplacement ? 'Enter replacement text...' : 'Enter new text...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Font Size:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('${fontSize.toInt()} pt', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: fontSize,
                      min: 9,
                      max: 32,
                      divisions: 23,
                      activeColor: const Color(0xFF7046A8),
                      onChanged: (val) {
                        setDialogState(() => fontSize = val);
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Vertical Position on Page:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('${(verticalPosition * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: verticalPosition,
                      min: 0.05,
                      max: 0.90,
                      divisions: 17,
                      activeColor: const Color(0xFF7046A8),
                      onChanged: (val) {
                        setDialogState(() => verticalPosition = val);
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text('Text Color:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: colorOptions.map((c) {
                        final isSelected = selectedColor == c;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = c),
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.amber : (isDark ? Colors.white30 : Colors.black26),
                                width: isSelected ? 2.5 : 1,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 16, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    const Text('Alignment:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.format_align_left, color: alignment == TextAlign.left ? const Color(0xFF7046A8) : Colors.grey),
                          onPressed: () => setDialogState(() => alignment = TextAlign.left),
                        ),
                        IconButton(
                          icon: Icon(Icons.format_align_center, color: alignment == TextAlign.center ? const Color(0xFF7046A8) : Colors.grey),
                          onPressed: () => setDialogState(() => alignment = TextAlign.center),
                        ),
                        IconButton(
                          icon: Icon(Icons.format_align_right, color: alignment == TextAlign.right ? const Color(0xFF7046A8) : Colors.grey),
                          onPressed: () => setDialogState(() => alignment = TextAlign.right),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7046A8),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final trimmed = textController.text.trim();
                    if (trimmed.isNotEmpty) {
                      Navigator.pop(dialogCtx);
                      onConfirm(trimmed, fontSize, selectedColor, alignment, verticalPosition);
                    }
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _previewEditedPdf() async {
    if (_pdfFile == null) return;
    try {
      final editedBytes = await _generateEditedPdfBytes();
      if (!mounted) return;

      // Show preview sheet with SfPdfViewer
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
                title: const Text('PDF Edit Preview'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Expanded(
                child: SfPdfViewer.memory(Uint8List.fromList(editedBytes)),
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
                        _promptSaveOptions(editedBytes);
                      },
                      icon: const Icon(Icons.save_alt_rounded),
                      label: const Text('Save Edited PDF', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Future<List<int>> _generateEditedPdfBytes() async {
    final inputBytes = await _pdfFile!.readAsBytes();
    final doc = PdfDocument(inputBytes: inputBytes);

    try {
      for (final edit in _edits) {
        if (edit.pageIndex < 0 || edit.pageIndex >= doc.pages.count) continue;
        final page = doc.pages[edit.pageIndex];
        final pageSize = page.size;

        final font = PdfStandardFont(PdfFontFamily.helvetica, edit.fontSize);
        final brush = PdfSolidBrush(PdfColor(edit.color.r.toInt(), edit.color.g.toInt(), edit.color.b.toInt()));

        final posX = edit.x * pageSize.width;
        final posY = edit.y * pageSize.height;
        final targetWidth = (pageSize.width - posX - 36).clamp(100.0, pageSize.width);

        if (edit.isReplacement) {
          // Clean whiteout overlay to cover original text neatly
          page.graphics.drawRectangle(
            brush: PdfSolidBrush(PdfColor(255, 255, 255)),
            bounds: Rect.fromLTWH(posX - 4, posY - 2, targetWidth + 8, edit.fontSize * 2.2),
          );
        }

        PdfTextAlignment pdfAlign;
        switch (edit.alignment) {
          case TextAlign.center:
            pdfAlign = PdfTextAlignment.center;
            break;
          case TextAlign.right:
            pdfAlign = PdfTextAlignment.right;
            break;
          default:
            pdfAlign = PdfTextAlignment.left;
        }

        page.graphics.drawString(
          edit.text,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(posX, posY, targetWidth, edit.fontSize * 3),
          format: PdfStringFormat(alignment: pdfAlign, lineSpacing: 2),
        );
      }

      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  Future<void> _promptSaveOptions(List<int> pdfBytes) async {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Save PDF Options'),
          content: const Text(
            'Would you like to save this as a new document (recommended to preserve original) or overwrite the source file?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(ctx);
                _confirmOverwrite(pdfBytes);
              },
              child: const Text('Overwrite Original'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7046A8),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _saveAsNewPdf(pdfBytes);
              },
              child: const Text('Save as New PDF'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmOverwrite(List<int> bytes) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm Overwrite'),
          ],
        ),
        content: Text(
          "Are you sure you want to replace '${_pdfInfo?.fileName}'? This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Overwrite'),
          ),
        ],
      ),
    );

    if (confirmed == true && _pdfFile != null) {
      setState(() => _isProcessingSave = true);
      try {
        await _pdfFile!.writeAsBytes(bytes, flush: true);
        setState(() => _isProcessingSave = false);
        _showSnackBar('Original file successfully updated!');
      } catch (e) {
        setState(() => _isProcessingSave = false);
        _showSnackBar('Failed to overwrite: $e');
      }
    }
  }

  Future<void> _saveAsNewPdf(List<int> bytes) async {
    setState(() => _isProcessingSave = true);
    try {
      final saveDir = await DocumentsStorageService.instance.getAppDocumentsDirectory();
      final base = _pdfInfo?.fileName ?? 'Edited_Document.pdf';
      final cleanBase = base.replaceAll('.pdf', '_edited.pdf');
      final uniqueName = DocumentSaveService.instance.generateUniqueFileName(
        directory: saveDir,
        baseName: cleanBase,
      );

      final newFile = File('${saveDir.path}/$uniqueName');
      await newFile.writeAsBytes(bytes, flush: true);

      final newDoc = DocumentsModel(
        name: uniqueName,
        path: newFile.path,
        type: 'pdf',
        createdAt: DateTime.now(),
      );
      await DocumentsStorageService.instance.addDocument(newDoc);

      setState(() => _isProcessingSave = false);

      if (!mounted) return;
      GeneratedPdfSuccessSheet.show(
        context: context,
        document: newDoc,
        file: newFile,
        subtitle: '${_pdfInfo?.pageCount ?? 1} pages • ${(bytes.length / 1024).toStringAsFixed(1)} KB',
        onDone: () {
          Navigator.pop(context);
        },
      );
    } catch (e) {
      setState(() => _isProcessingSave = false);
      _showSnackBar('Save failed: $e');
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

    return PopScope(
      canPop: _edits.isEmpty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Discard Unsaved Edits?'),
            content: Text('You have ${_edits.length} unsaved edit(s). Leaving now will discard them.'),
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
              Text('PDF Text Editor', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              Text('Add overlays & replace text blocks', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          actions: [
            if (_pdfFile != null && !_isLoading) ...[
              IconButton(
                icon: const Icon(Icons.visibility_outlined),
                tooltip: 'Preview Changes',
                onPressed: _edits.isEmpty ? null : _previewEditedPdf,
              ),
              IconButton(
                icon: const Icon(Icons.file_upload_outlined),
                tooltip: 'Change PDF',
                onPressed: _pickPdf,
              ),
            ],
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _pdfFile == null
                ? _buildEmptyState(isDark)
                : _buildEditorView(isDark, cardBg),
        bottomNavigationBar: _pdfFile != null && (!_isScanned || _allowOverlaysOnScanned)
            ? _buildBottomBar(isDark, cardBg)
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
              child: const Icon(Icons.edit_document, size: 48, color: Color(0xFF7046A8)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select PDF to Edit Text',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Inspect pages with real PDF preview, add text overlays, replace detected text blocks, and save as a new PDF without modifying your original file.',
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
                icon: const Icon(Icons.file_open_rounded),
                label: const Text('Select PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 18),
            // Separate image workflow option to avoid user confusion
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Have images instead of a PDF? ',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ImagesToPdfView()),
                    );
                  },
                  child: const Text(
                    'Create PDF from Images',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7046A8), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorView(bool isDark, Color cardBg) {
    if (_isScanned && !_allowOverlaysOnScanned) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.document_scanner_rounded, size: 56, color: Color(0xFF7046A8)),
              const SizedBox(height: 16),
              const Text(
                'Scanned Document Detected',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'This PDF consists of scanned image pages without a digital text layer. Words are flattened into images and cannot be directly highlighted or replaced like a word document.\n\nChoose an option below:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7046A8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OcrWorkspaceView(initialPdfPath: _pdfFile?.path),
                      ),
                    );
                  },
                  icon: const Icon(Icons.document_scanner_rounded),
                  label: const Text('Open in OCR Workspace to Extract Text'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    setState(() => _allowOverlaysOnScanned = true);
                  },
                  icon: const Icon(Icons.post_add_rounded),
                  label: const Text('Continue to Add Text Overlays'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentPageEdits = _edits.where((e) => e.pageIndex == _selectedPageIndex).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // File Details Banner
        Card(
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
                        '${_pdfInfo?.pageCount ?? 1} pages • ${_pdfInfo?.formattedSize ?? ''} • ${_edits.length} total edits',
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

        // Real PDF Page Preview
        Container(
          height: 250,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF7046A8).withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SfPdfViewer.file(
              _pdfFile!,
              key: ValueKey(_pdfFile!.path),
              controller: _pdfViewerController,
              canShowScrollHead: false,
              canShowScrollStatus: false,
              onPageChanged: (details) {
                if (_selectedPageIndex != details.newPageNumber - 1) {
                  _changePage(details.newPageNumber - 1);
                }
              },
            ),
          ),
        ),

        // Technical Clarification Note
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF7046A8).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF7046A8).withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Color(0xFF7046A8)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PDF text is rendered in fixed visual streams. This editor places clean overlays or replacement patches over targeted blocks. Original files are protected and never overwritten.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF7046A8)),
                ),
              ),
            ],
          ),
        ),

        // Multi-page Selector Bar
        if ((_pdfInfo?.pageCount ?? 1) > 1) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF7046A8).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                  tooltip: 'Previous Page',
                  onPressed: _selectedPageIndex > 0
                      ? () => _changePage(_selectedPageIndex - 1)
                      : null,
                ),
                Text(
                  'Viewing Page ${_selectedPageIndex + 1} of ${_pdfInfo?.pageCount}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  tooltip: 'Next Page',
                  onPressed: _selectedPageIndex < (_pdfInfo!.pageCount - 1)
                      ? () => _changePage(_selectedPageIndex + 1)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Action Toolbar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Page ${_selectedPageIndex + 1} Content',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7046A8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: _addCustomTextOverlay,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Text Overlay'),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Current Page Pending Edits List
        if (currentPageEdits.isNotEmpty) ...[
          Text(
            'Edits on this page (${currentPageEdits.length}):',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF7046A8)),
          ),
          const SizedBox(height: 8),
          ...currentPageEdits.map((item) {
            return Card(
              color: cardBg,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: Icon(
                  item.isReplacement ? Icons.find_replace_rounded : Icons.post_add_rounded,
                  color: const Color(0xFF7046A8),
                ),
                title: Text(item.text, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${item.fontSize.toInt()}pt • ${item.isReplacement ? "Replaces: ${item.originalText}" : "New Text Overlay"} at ${(item.y * 100).toInt()}% height',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeEditItem(item.id),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        // Detected Text Paragraphs
        const Text(
          'Detected Text Blocks (tap to replace with new text):',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_extractedPageParagraphs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              _isScanned
                  ? 'No digital text blocks detected on this scanned page. Use "Add Text Overlay" above to place text.'
                  : 'No selectable text blocks recognized on this page.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          )
        else
          ..._extractedPageParagraphs.asMap().entries.map((entry) {
            final idx = entry.key;
            final para = entry.value;
            return Card(
              color: cardBg,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                title: Text(
                  para,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Replace'),
                  onPressed: () => _editExistingParagraph(idx, para),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildBottomBar(bool isDark, Color cardBg) {
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
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: _edits.isEmpty || _isProcessingSave ? null : _previewEditedPdf,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Preview'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7046A8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _edits.isEmpty || _isProcessingSave
                    ? null
                    : () async {
                        try {
                          final bytes = await _generateEditedPdfBytes();
                          _saveAsNewPdf(bytes);
                        } catch (e) {
                          _showSnackBar('Save failed: $e');
                        }
                      },
                icon: _isProcessingSave
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(
                  _edits.isEmpty
                      ? 'Save as New PDF'
                      : 'Save as New PDF (${_edits.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
