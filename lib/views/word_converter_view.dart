import 'dart:io';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/document_converter_service.dart';
import 'package:all_documents_reader/services/document_save_service.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/views/ocr_workspace_view.dart';
import 'package:all_documents_reader/widgets/generated_pdf_success_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

enum WordConversionMode {
  pdfToWord,
  wordToPdf,
}

/// Offline OpenXML (.docx) and PDF document conversion screen
class WordConverterView extends StatefulWidget {
  final WordConversionMode mode;

  const WordConverterView({super.key, required this.mode});

  @override
  State<WordConverterView> createState() => _WordConverterViewState();
}

class _WordConverterViewState extends State<WordConverterView> {
  late WordConversionMode _currentMode;
  bool get isPdfToWord => _currentMode == WordConversionMode.pdfToWord;

  File? _selectedFile;
  ConversionAssessment? _assessment;
  bool _isAssessing = false;
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.mode;
  }

  Future<void> _pickFile() async {
    try {
      final allowed = isPdfToWord ? ['pdf'] : ['docx', 'doc'];
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowed,
      );

      if (result.isEmpty || result.first.path == null) return;
      final path = result.first.path!;
      final file = File(path);

      if (!file.existsSync() || file.lengthSync() == 0) {
        _showSnackBar('Selected file does not exist or is empty.');
        return;
      }

      setState(() {
        _selectedFile = file;
        _isAssessing = true;
        _assessment = null;
      });

      final assessment = isPdfToWord
          ? await DocumentConverterService.instance.assessPdf(file.path)
          : await DocumentConverterService.instance.assessDocx(file.path);

      setState(() {
        _assessment = assessment;
        _isAssessing = false;
      });
    } catch (e) {
      setState(() => _isAssessing = false);
      _showSnackBar('File selection error: $e');
    }
  }

  Future<void> _performConversion() async {
    if (_selectedFile == null || _isConverting) return;

    setState(() => _isConverting = true);

    try {
      if (isPdfToWord) {
        final docxFile = await DocumentConverterService.instance.convertPdfToDocx(
          pdfPath: _selectedFile!.path,
        );

        final doc = DocumentsModel(
          name: docxFile.path.split(RegExp(r'[/\\]')).last,
          path: docxFile.path,
          type: 'docx',
          createdAt: DateTime.now(),
        );
        await DocumentsStorageService.instance.addDocument(doc);

        setState(() => _isConverting = false);
        if (!mounted) return;

        _showDocxSuccessDialog(doc, docxFile);
      } else {
        final pdfFile = await DocumentConverterService.instance.convertDocxToPdf(
          docxPath: _selectedFile!.path,
        );

        final doc = DocumentsModel(
          name: pdfFile.path.split(RegExp(r'[/\\]')).last,
          path: pdfFile.path,
          type: 'pdf',
          createdAt: DateTime.now(),
        );
        await DocumentsStorageService.instance.addDocument(doc);

        setState(() => _isConverting = false);
        if (!mounted) return;

        GeneratedPdfSuccessSheet.show(
          context: context,
          document: doc,
          file: pdfFile,
          subtitle: 'Cleanly converted to standard vector PDF',
          onDone: () => Navigator.pop(context),
        );
      }
    } catch (e) {
      setState(() => _isConverting = false);
      _showSnackBar('Conversion failed: $e');
    }
  }

  void _showDocxSuccessDialog(DocumentsModel document, File file) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text('Word Document Ready', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Generated Microsoft Word (.docx) document:", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text(document.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Text(
              'Saved to: ${file.path}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF7046A8).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'This file is formatted to modern Office Open XML standards and opens in Microsoft Word, Google Docs, and WPS Office.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF7046A8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text('Share'),
            onPressed: () {
              // ignore: deprecated_member_use
              Share.shareXFiles([XFile(file.path)], text: document.name);
            },
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open Word'),
            onPressed: () {
              OpenFilex.open(file.path);
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7046A8),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.save_alt_rounded, size: 16),
            label: const Text('Save to Device'),
            onPressed: () async {
              Navigator.pop(ctx);
              await DocumentSaveService.instance.saveDocumentToDevice(
                context: context,
                sourceFile: file,
                defaultFileName: document.name,
              );
            },
          ),
        ],
      ),
    );
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
    final primaryText = isDark ? Colors.white : const Color(0xFF2D2435);
    final secondaryText = isDark ? const Color(0xFFB0A9B8) : const Color(0xFF6C6374);
    final cardBg = isDark ? const Color(0xFF211C29) : Colors.white;

    final title = isPdfToWord ? 'PDF to Word' : 'Word to PDF';
    const accentColor = Color(0xFF7046A8);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isPdfToWord ? 'PDF to Word Converter' : 'Word to PDF Converter',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(
              isPdfToWord ? 'Convert digital PDF to editable Word (.docx)' : 'Convert Word (.docx) into vector PDF',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Segmented Mode Switcher
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2535) : const Color(0xFFEDE9F2),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        if (_currentMode != WordConversionMode.pdfToWord) {
                          setState(() {
                            _currentMode = WordConversionMode.pdfToWord;
                            _selectedFile = null;
                            _assessment = null;
                            _isAssessing = false;
                            _isConverting = false;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isPdfToWord ? const Color(0xFF7046A8) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 16,
                              color: isPdfToWord ? Colors.white : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'PDF to Word',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isPdfToWord ? Colors.white : secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        if (_currentMode != WordConversionMode.wordToPdf) {
                          setState(() {
                            _currentMode = WordConversionMode.wordToPdf;
                            _selectedFile = null;
                            _assessment = null;
                            _isAssessing = false;
                            _isConverting = false;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isPdfToWord ? const Color(0xFF7046A8) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.description_rounded,
                              size: 16,
                              color: !isPdfToWord ? Colors.white : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Word to PDF',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: !isPdfToWord ? Colors.white : secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.25 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPdfToWord ? Icons.article_outlined : Icons.description_outlined,
                size: 38,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isPdfToWord
                  ? 'Convert digital PDF headings, paragraphs, and structure into an editable Word (.docx) document.'
                  : 'Convert Microsoft Word (.docx) documents into clean, paginated vector PDF files.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: secondaryText, height: 1.4),
            ),
            const SizedBox(height: 20),

            // Active Converter Card
            Card(
              color: cardBg,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: accentColor.withValues(alpha: 0.25)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.transform_rounded, color: accentColor, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          isPdfToWord ? 'Select PDF to Convert' : 'Select Word Document (.docx)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (_selectedFile == null)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isAssessing ? null : _pickFile,
                        icon: const Icon(Icons.file_open_rounded),
                        label: Text(
                          isPdfToWord ? 'Select PDF' : 'Select Word Document (.docx)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                      )
                    else ...[
                      // File Details Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2535) : const Color(0xFFF7F5FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isPdfToWord ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                              color: isPdfToWord ? Colors.red : accentColor,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedFile!.path.split(RegExp(r'[/\\]')).last,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${(_selectedFile!.lengthSync() / 1024).toStringAsFixed(1)} KB',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (_isAssessing)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_assessment != null) ...[
                        // Scanned PDF Warning Banner with direct OCR link
                        if (_assessment!.isScannedOrEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber.shade700),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 20),
                                    const SizedBox(width: 8),
                                    const Text('Scanned PDF Detected', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'This PDF appears to be a scanned image without a digital text layer. Converting without OCR will produce a document without text.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF7046A8)),
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => OcrWorkspaceView(initialPdfPath: _selectedFile?.path),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.document_scanner_rounded, size: 16),
                                    label: const Text('Open in OCR Workspace Instead'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          // Structure summary
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Detected ${_assessment!.estimatedParagraphs} paragraph(s)${_assessment!.estimatedTables > 0 ? " and ${_assessment!.estimatedTables} table(s)" : ""}',
                                  style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isConverting ? null : _pickFile,
                                child: const Text('Change File'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _isConverting ? null : _performConversion,
                                icon: _isConverting
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.check_rounded, size: 18),
                                label: Text(
                                  _isConverting
                                      ? 'Converting...'
                                      : isPdfToWord
                                          ? 'Convert to Word (.docx)'
                                          : 'Convert to PDF',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Conversion Information Card
            Card(
              color: cardBg,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: accentColor, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'How Offline Conversion Works',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isPdfToWord
                          ? '• Extracts digital text streams and reconstructs them into styled OpenXML paragraphs, headings, and tables.\n• Works 100% offline and privately on your device without sending documents to third-party servers.\n• Scanned or photo-based PDFs require optical character recognition (OCR) first.'
                          : '• Reads standard OpenXML Word (.docx) document packages.\n• Compiles paragraphs, headings, and tables into clean vector PDF pages with consistent margins and typography.\n• Safe offline processing preserves document privacy.',
                      style: TextStyle(fontSize: 12.5, color: secondaryText, height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
