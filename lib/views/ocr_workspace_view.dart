import 'dart:io';
import 'package:all_documents_reader/core/config/app_config.dart';
import 'package:all_documents_reader/services/ocr_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:all_documents_reader/services/pdf_to_image_service.dart';
import 'package:all_documents_reader/views/ai_document_assistant_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Comprehensive OCR Workspace supporting Images, Camera Scans, and PDFs
class OcrWorkspaceView extends StatefulWidget {
  final String? initialImagePath;
  final String? initialPdfPath;

  const OcrWorkspaceView({
    super.key,
    this.initialImagePath,
    this.initialPdfPath,
  });

  @override
  State<OcrWorkspaceView> createState() => _OcrWorkspaceViewState();
}

class _OcrWorkspaceViewState extends State<OcrWorkspaceView> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _textController = TextEditingController();
  final List<String> _selectedSourcePaths = [];

  bool _isRecognizing = false;
  String _statusMessage = '';
  String? _ocrError;
  bool _isSavedAsDoc = false;

  int _wordCount = 0;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_updateCounts);

    if (widget.initialImagePath != null) {
      _selectedSourcePaths.add(widget.initialImagePath!);
      _processSelectedSources();
    } else if (widget.initialPdfPath != null) {
      _selectedSourcePaths.add(widget.initialPdfPath!);
      _processSelectedSources();
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_updateCounts);
    _textController.dispose();
    super.dispose();
  }

  void _updateCounts() {
    final text = _textController.text;
    final words = text.trim().isEmpty
        ? 0
        : text.trim().split(RegExp(r'\s+')).length;
    setState(() {
      _wordCount = words;
      _charCount = text.length;
    });
  }

  // --- Input Sources ---

  Future<void> _pickImagesFromGallery() async {
    try {
      final List<PlatformFile> pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
      );

      if (pickedFiles.isEmpty) return;

      final paths = pickedFiles
          .map((f) => f.path)
          .where((p) => p != null && File(p).existsSync())
          .cast<String>()
          .toList();

      if (paths.isNotEmpty) {
        setState(() {
          _selectedSourcePaths.clear();
          _selectedSourcePaths.addAll(paths);
        });
        _processSelectedSources();
      }
    } catch (e) {
      _showSnackBar('Failed to select images: $e');
    }
  }

  Future<void> _captureFromCamera() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );

      if (photo != null && File(photo.path).existsSync()) {
        setState(() {
          _selectedSourcePaths.clear();
          _selectedSourcePaths.add(photo.path);
        });
        _processSelectedSources();
      }
    } catch (e) {
      _showSnackBar('Camera access error: $e');
    }
  }

  Future<void> _pickPdfDocument() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result.isEmpty || result.first.path == null) return;
      final path = result.first.path!;

      if (File(path).existsSync()) {
        setState(() {
          _selectedSourcePaths.clear();
          _selectedSourcePaths.add(path);
        });
        _processSelectedSources();
      }
    } catch (e) {
      _showSnackBar('Failed to pick PDF: $e');
    }
  }

  // --- Multi-Page OCR Processing ---

  Future<void> _processSelectedSources() async {
    if (_selectedSourcePaths.isEmpty || _isRecognizing) return;

    setState(() {
      _isRecognizing = true;
      _ocrError = null;
      _statusMessage = 'Preparing document for OCR...';
      _isSavedAsDoc = false;
    });

    final StringBuffer buffer = StringBuffer();

    try {
      for (int i = 0; i < _selectedSourcePaths.length; i++) {
        final src = _selectedSourcePaths[i];
        final lower = src.toLowerCase();

        if (lower.endsWith('.pdf')) {
          // PDF Processing: 1. Try digital text stream
          setState(() {
            _statusMessage = 'Reading text layer from PDF...';
          });

          String pdfText = '';
          try {
            final pdfRes = await PdfOperationsService.instance.extractTextFromPdf(pdfPath: src);
            pdfText = pdfRes.text;
          } catch (_) {}

          if (pdfText.trim().isNotEmpty) {
            buffer.writeln('=== PDF Text Content ===');
            buffer.writeln(pdfText.trim());
            buffer.writeln();
          } else {
            // Scanned PDF: Render pages to images and run ML Kit OCR
            setState(() {
              _statusMessage = 'Rasterizing scanned PDF pages for OCR...';
            });

            final info = await PdfOperationsService.instance.inspectPdf(src);
            final pageIndices = List.generate(info.pageCount, (idx) => idx + 1);

            final imgResult = await PdfToImageService.instance.convertPdfToImages(
              pdfPath: src,
              pageNumbers: pageIndices,
            );

            for (int p = 0; p < imgResult.generatedFiles.length; p++) {
              final pageImgFile = imgResult.generatedFiles[p];
              setState(() {
                _statusMessage =
                    'Extracting page ${p + 1} of ${imgResult.generatedFiles.length}...';
              });

              final pageOcr =
                  await OcrService.instance.recognizeTextFromImage(pageImgFile.path);
              if (pageOcr.text.trim().isNotEmpty) {
                buffer.writeln('--- Page ${p + 1} ---');
                buffer.writeln(pageOcr.text.trim());
                buffer.writeln();
              }
            }
          }
        } else {
          // Image file processing via ML Kit
          setState(() {
            _statusMessage =
                'Running OCR on image ${i + 1} of ${_selectedSourcePaths.length}...';
          });

          final ocrRes = await OcrService.instance.recognizeTextFromImage(src);
          if (ocrRes.text.trim().isNotEmpty) {
            if (_selectedSourcePaths.length > 1) {
              buffer.writeln('--- Page ${i + 1} ---');
            }
            buffer.writeln(ocrRes.text.trim());
            buffer.writeln();
          }
        }
      }

      final finalText = buffer.toString().trim();

      if (!mounted) return;
      if (finalText.isEmpty) {
        setState(() {
          _isRecognizing = false;
          _ocrError =
              'No readable text detected. Please ensure the document is clear, well-lit, and contains Latin-based text.';
        });
      } else {
        setState(() {
          _isRecognizing = false;
          _textController.text = finalText;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecognizing = false;
        _ocrError = e is UnsupportedError
            ? 'On-device OCR runs natively on Android and iOS devices.'
            : 'OCR extraction encountered an error: $e';
      });
    }
  }

  // --- Toolbar Actions ---

  void _copyToClipboard() {
    if (_textController.text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _textController.text));
    _showSnackBar('Recognized text copied to clipboard!');
  }

  void _selectAllText() {
    if (_textController.text.isEmpty) return;
    _textController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _textController.text.length,
    );
    _showSnackBar('All text selected.');
  }

  void _clearText() {
    if (_textController.text.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Text?'),
        content: const Text('Remove all recognized text from editor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _textController.clear();
            },
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAsDocument() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSavedAsDoc) return;

    try {
      final doc = await OcrService.instance.saveExtractedTextAsDocument(
        text: text,
      );

      if (!mounted) return;
      setState(() => _isSavedAsDoc = true);
      _showSnackBar('Saved "${doc.name}" to Documents!');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to save document: $e');
    }
  }

  void _sendToAiAssistant() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showSnackBar('Extract or enter text first before analyzing with AI.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AiDocumentAssistantView(
          initialText: text,
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = theme.primaryColor;
    final surfaceColor = isDark ? const Color(0xFF1E1926) : Colors.white;
    final bgLight = isDark ? const Color(0xFF14101A) : const Color(0xFFF7F6FA);

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.document_scanner_rounded, size: 22),
            SizedBox(width: 8),
            Text('OCR Workspace'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Re-run OCR',
            onPressed: _selectedSourcePaths.isNotEmpty && !_isRecognizing
                ? _processSelectedSources
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF9D65E5)),
            tooltip: 'Analyze with AI',
            onPressed: _textController.text.isNotEmpty ? _sendToAiAssistant : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Source Picker Bar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select OCR Source:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _captureFromCamera,
                          icon: const Icon(Icons.camera_alt_rounded, size: 16),
                          label: const Text('Camera'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickImagesFromGallery,
                          icon: const Icon(Icons.photo_library_rounded, size: 16),
                          label: const Text('Images'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickPdfDocument,
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                          label: const Text('PDF'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedSourcePaths.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Selected ${_selectedSourcePaths.length} item(s): ${_selectedSourcePaths.map((p) => p.split(RegExp(r'[/\\]')).last).join(', ')}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Engine Disclosure Note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFF7046A8)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'On-device Latin script OCR engine. Processing is completely private and offline.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF7046A8)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Error Banner
            if (_ocrError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _ocrError!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.amber[200] : Colors.amber[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 4. Progress or Text Editor
            if (_isRecognizing) ...[
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: primaryColor),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Extracting character contours and words',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Text Toolbar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_wordCount words • $_charCount characters',
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.select_all_rounded, size: 20),
                        tooltip: 'Select All',
                        onPressed: _selectAllText,
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        tooltip: 'Copy Text',
                        onPressed: _copyToClipboard,
                      ),
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        tooltip: 'Clear Editor',
                        onPressed: _clearText,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Multi-line Text Field
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _textController,
                  maxLines: 14,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF2D2435),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Recognized text will appear here. You can also type or paste directly...',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bottom Actions: Save, Re-run, and Send to AI
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSavedAsDoc ? null : _saveAsDocument,
                      icon: Icon(_isSavedAsDoc ? Icons.check : Icons.save_rounded, size: 16),
                      label: Text(_isSavedAsDoc ? 'Saved TXT' : 'Save as .TXT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7046A8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (AppConfig.isAiFeatureEnabled) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _textController.text.isNotEmpty ? _sendToAiAssistant : null,
                        icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                        label: const Text('AI Assistant'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7046A8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
