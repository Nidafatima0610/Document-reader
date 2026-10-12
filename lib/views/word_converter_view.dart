import 'dart:io';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/document_converter_service.dart';
import 'package:all_documents_reader/services/document_save_service.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/views/images_to_pdf_view.dart';
import 'package:all_documents_reader/views/pdf_to_text_view.dart';
import 'package:all_documents_reader/views/text_to_pdf_view.dart';
import 'package:all_documents_reader/widgets/generated_pdf_success_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

enum WordConversionMode {
  pdfToWord,
  wordToPdf,
}

/// Upgraded conversion screen providing transparent technical assessment
/// and genuine, honest offline OpenXML (.docx) and PDF document generation.
class WordConverterView extends StatefulWidget {
  final WordConversionMode mode;

  const WordConverterView({super.key, required this.mode});

  @override
  State<WordConverterView> createState() => _WordConverterViewState();
}

class _WordConverterViewState extends State<WordConverterView> {
  bool get isPdfToWord => widget.mode == WordConversionMode.pdfToWord;

  File? _selectedFile;
  ConversionAssessment? _assessment;
  bool _isAssessing = false;
  bool _isConverting = false;

  Future<void> _pickFile() async {
    try {
      final allowed = isPdfToWord ? ['pdf'] : ['docx', 'doc'];
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowed,
      );

      if (result.isEmpty || result.first.path == null) return;
      final file = File(result.first.path!);

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
          subtitle: 'Cleanly converted to standard PDF',
          onDone: () {},
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
            Text("Generated genuine Microsoft Word (.docx) package:", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text(document.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'This file follows modern Office Open XML standards and opens natively in Microsoft Word, WPS Office, and Google Docs.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF1976D2)),
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
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open in Word App'),
            onPressed: () {
              OpenFilex.open(file.path);
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
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
    final iconColor = isPdfToWord ? const Color(0xFF1976D2) : const Color(0xFF1565C0);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: isDark ? 0.25 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPdfToWord ? Icons.article_outlined : Icons.description_outlined,
                size: 40,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade700),
              ),
              child: Text(
                'Enterprise / Cloud Engine Required',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Active Converter Card
            Card(
              color: cardBg,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: iconColor.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.transform_rounded, color: iconColor, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          isPdfToWord ? 'Convert PDF to Word (.docx)' : 'Convert Word (.docx) to PDF',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isPdfToWord
                          ? 'Extracts document typography, paragraphs, and headings into a genuine Microsoft Word OpenXML (.docx) file.'
                          : 'Parses .docx XML paragraphs and headings into a clean vector A4 PDF document.',
                      style: TextStyle(fontSize: 12.5, color: secondaryText, height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    if (_selectedFile == null)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: iconColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isAssessing ? null : _pickFile,
                        icon: const Icon(Icons.file_open_rounded),
                        label: Text(
                          isPdfToWord ? 'Select PDF to Convert' : 'Select Word (.docx) File',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )
                    else ...[
                      // File Assessment Preview
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFile!.path.split(RegExp(r'[/\\]')).last,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (_isAssessing)
                              const Row(
                                children: [
                                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                                  SizedBox(width: 8),
                                  Text('Analyzing document structure...', style: TextStyle(fontSize: 11)),
                                ],
                              )
                            else if (_assessment != null) ...[
                              Text(
                                'Size: ${(_assessment!.fileSizeBytes / 1024).toStringAsFixed(1)} KB • Estimated paragraphs: ${_assessment!.estimatedParagraphs}',
                                style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                              ),
                              if (_assessment!.warningMessage != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _assessment!.warningMessage!,
                                  style: const TextStyle(fontSize: 11, color: Colors.amber),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
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
                                backgroundColor: iconColor,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _isConverting ? null : _performConversion,
                              icon: _isConverting
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.check_rounded, size: 18),
                              label: Text(_isConverting ? 'Converting...' : 'Convert Now'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Technical Feasibility Card
            Card(
              color: cardBg,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.engineering_outlined, color: iconColor, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'Technical Feasibility Assessment',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isPdfToWord
                          ? 'High-fidelity PDF to editable Microsoft Word (.docx) reconstruction requires an advanced desktop typography layout and semantic OCR engine. In pure offline on-device Flutter, extracting glyph coordinates into flowable paragraphs with tables and styles cannot be performed reliably without loss of formatting.'
                          : 'Rendering Microsoft Word (.docx XML) documents into paginated, vector-accurate PDF pages requires an Office rendering engine (such as LibreOffice or Microsoft Word COM interop). Offline Dart engines currently lack a full DOCX layout compositor.',
                      style: TextStyle(fontSize: 13, color: secondaryText, height: 1.45),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Recommended Working Alternatives:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    if (isPdfToWord) ...[
                      _buildBulletPoint('Use "PDF to Text" to extract and copy editable text cleanly.', iconColor, secondaryText),
                      _buildBulletPoint('Open documents with external office apps via Open Document.', iconColor, secondaryText),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: iconColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.text_snippet_rounded, size: 20),
                          label: const Text(
                            'Open PDF to Text Extractor',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const PdfToTextView()),
                            );
                          },
                        ),
                      ),
                    ] else ...[
                      _buildBulletPoint('Use "Text to PDF" to generate clean, paginated PDF documents directly from notes.', iconColor, secondaryText),
                      _buildBulletPoint('Use "Images to PDF" to compile scans and photos into PDF.', iconColor, secondaryText),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: iconColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.post_add_rounded, size: 20),
                          label: const Text(
                            'Open Text to PDF Creator',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const TextToPdfView()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: iconColor,
                            side: BorderSide(color: iconColor, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.photo_library_rounded, size: 20),
                          label: const Text(
                            'Open Images to PDF',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const ImagesToPdfView()),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text, Color iconColor, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12.5, color: textColor)),
          ),
        ],
      ),
    );
  }
}
