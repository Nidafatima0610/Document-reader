import 'dart:io';
import 'package:all_documents_reader/core/config/app_config.dart';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/models/scanned_page_model.dart';
import 'package:all_documents_reader/services/ad_mob_service.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/ocr_service.dart';
import 'package:all_documents_reader/services/pdf_generator_service.dart';
import 'package:all_documents_reader/views/ai_document_assistant_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:all_documents_reader/views/pdf_viewer_screen.dart';
import 'package:all_documents_reader/views/smart_scanner_view.dart';

/// Results and post-scan actions view: View PDF, perform OCR, copy or save text
class ScannerResultView extends StatefulWidget {
  final PdfGenerationResult pdfResult;
  final DocumentsModel document;
  final List<ScannedPageModel> pages;

  const ScannerResultView({
    super.key,
    required this.pdfResult,
    required this.document,
    required this.pages,
  });

  @override
  State<ScannerResultView> createState() => _ScannerResultViewState();
}

class _ScannerResultViewState extends State<ScannerResultView> {
  bool _isPerformingOcr = false;
  String? _extractedText;
  String? _ocrError;
  bool _isSavingTxt = false;
  bool _txtSaved = false;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _openPdfViewer() {
    DocumentsStorageService.instance.recordDocumentOpened(widget.document);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          file: widget.pdfResult.file,
          title: widget.document.name,
          document: widget.document,
        ),
      ),
    );
  }

  bool get isHighPrecisionOcrUnlocked =>
      AdMobService.instance.isPerkUnlocked('scanner_high_precision_ocr');

  Future<void> _handleOcrExtraction({required bool highPrecision}) async {
    if (highPrecision) {
      if (isHighPrecisionOcrUnlocked) {
        await _runOcr(highPrecision: true);
        return;
      }

      final unlocked = await AdMobService.instance.showRewardedAdPrompt(
        context,
        title: 'Unlock High-Precision OCR',
        description:
            'Watch a short ad to extract text with document scan metrics, word counts, and page delimiters.',
        perkKey: 'scanner_high_precision_ocr',
      );

      if (unlocked && mounted) {
        await _runOcr(highPrecision: true);
      } else if (!unlocked && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Standard OCR remains completely free.'),
          ),
        );
      }
      return;
    }

    await _runOcr(highPrecision: false);
  }

  Future<void> _runOcr({bool highPrecision = false}) async {
    if (_isPerformingOcr) return;

    setState(() {
      _isPerformingOcr = true;
      _ocrError = null;
    });

    try {
      final StringBuffer combinedBuffer = StringBuffer();
      int processedPages = 0;
      int totalWordCount = 0;
      int totalCharCount = 0;
      final List<String> pageTexts = [];

      for (int i = 0; i < widget.pages.length; i++) {
        final page = widget.pages[i];
        final file = File(page.processedImagePath);
        if (!file.existsSync()) continue;

        try {
          final result = await OcrService.instance.recognizeTextFromImage(file.path);
          final trimmed = result.text.trim();
          if (trimmed.isNotEmpty) {
            pageTexts.add(trimmed);
            totalWordCount += RegExp(r'\S+').allMatches(trimmed).length;
            totalCharCount += trimmed.length;
            processedPages++;
          } else {
            pageTexts.add('');
          }
        } catch (e) {
          debugPrint('Error on page ${i + 1} OCR: $e');
          // If unsupported error on desktop, rethrow to display informative message
          if (e is UnsupportedError) {
            rethrow;
          }
        }
      }

      if (highPrecision) {
        combinedBuffer.writeln('═══════════════════════════════════════════════════');
        combinedBuffer.writeln('DOCUMENT SCAN OCR REPORT');
        combinedBuffer.writeln('Document: ${widget.document.name}');
        combinedBuffer.writeln('Total Pages Scanned: ${widget.pages.length}');
        combinedBuffer.writeln('Processed Pages: $processedPages');
        combinedBuffer.writeln('Total Words: $totalWordCount • Total Characters: $totalCharCount');
        combinedBuffer.writeln('Extraction Engine: On-Device MLKit (High Precision)');
        combinedBuffer.writeln('═══════════════════════════════════════════════════\n');

        for (int i = 0; i < pageTexts.length; i++) {
          final pText = pageTexts[i];
          if (pText.isNotEmpty) {
            combinedBuffer.writeln('--- Page ${i + 1} of ${widget.pages.length} ---');
            combinedBuffer.writeln(pText);
            combinedBuffer.writeln();
          }
        }
      } else {
        for (int i = 0; i < pageTexts.length; i++) {
          final pText = pageTexts[i];
          if (pText.isNotEmpty) {
            if (widget.pages.length > 1) {
              combinedBuffer.writeln('--- Page ${i + 1} ---');
            }
            combinedBuffer.writeln(pText);
            combinedBuffer.writeln();
          }
        }
      }

      final text = combinedBuffer.toString().trim();
      if (!mounted) return;

      if (text.isEmpty) {
        setState(() {
          _isPerformingOcr = false;
          _ocrError = processedPages == 0
              ? 'No readable text was detected in the scanned document.'
              : 'Text extraction returned empty content.';
        });
      } else {
        setState(() {
          _isPerformingOcr = false;
          _extractedText = text;
          _textController.text = text;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPerformingOcr = false;
        _ocrError = e is UnsupportedError
            ? 'On-device OCR is supported natively on Android & iOS devices.'
            : 'OCR extraction failed: $e';
      });
    }
  }

  Future<void> _copyTextToClipboard() async {
    if (_textController.text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _textController.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Extracted text copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveAsTxtDocument() async {
    if (_textController.text.trim().isEmpty || _isSavingTxt) return;

    setState(() {
      _isSavingTxt = true;
    });

    try {
      final baseName = widget.document.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      final savedDoc = await OcrService.instance.saveExtractedTextAsDocument(
        text: _textController.text,
        customFileName: '${baseName}_OCR.txt',
      );

      if (!mounted) return;
      setState(() {
        _isSavingTxt = false;
        _txtSaved = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Saved "${savedDoc.name}" to Documents!'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSavingTxt = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Failed to save text file: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = theme.primaryColor;
    final primaryText = isDark ? Colors.white : const Color(0xFF2D2435);
    final secondaryText = isDark ? const Color(0xFFB0A9B8) : const Color(0xFF6C6374);
    final cardBg = isDark ? const Color(0xFF211C29) : Colors.white;
    final surfaceBg = isDark ? const Color(0xFF16121E) : const Color(0xFFF7F6FA);

    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        title: const Text('Scan Complete'),
        actions: [
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await AdMobService.instance.showInterstitialAd(
                context: context,
                triggerReason: 'scanner_workflow_done',
              );
              if (mounted) {
                nav.popUntil((route) => route.isFirst);
              }
            },
            child: const Text(
              'Done',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Success Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Document Scanned & Saved!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Added to local storage and all documents list',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // PDF Details Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Colors.red,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.document.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.pdfResult.pageCount} ${widget.pdfResult.pageCount == 1 ? "page" : "pages"} • ${widget.pdfResult.formattedSize}',
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Open in PDF Viewer Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _openPdfViewer,
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text(
                        'Open PDF Document',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // OCR Extraction Section
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.document_scanner_outlined,
                          color: Color(0xFF6366F1),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Optical Character Recognition (OCR)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: primaryText,
                              ),
                            ),
                            Text(
                              'Extract editable text from scanned pages',
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  if (_extractedText == null) ...[
                    if (_isPerformingOcr) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('Extracting text from scanned pages...'),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      if (_ocrError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.amber, size: 20),
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
                        const SizedBox(height: 12),
                      ],
                      // Standard Free OCR
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () => _handleOcrExtraction(highPrecision: false),
                          icon: const Icon(Icons.text_snippet_outlined),
                          label: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Extract Text (Free)',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              SizedBox(width: 8),
                              Text(
                                '• Standard',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Rewarded High-Precision OCR with Document Metrics
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => _handleOcrExtraction(highPrecision: true),
                          icon: Icon(
                            isHighPrecisionOcrUnlocked
                                ? Icons.verified_rounded
                                : Icons.play_circle_outline_rounded,
                            size: 18,
                          ),
                          label: Text(
                            isHighPrecisionOcrUnlocked
                                ? 'High-Precision OCR & Metrics (Unlocked)'
                                : 'High-Precision OCR & Metrics (Watch Ad)',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ] else ...[
                    // Text extracted successfully
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recognized Text:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: secondaryText,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.select_all_rounded, size: 20),
                              tooltip: 'Select All',
                              onPressed: () {
                                _textController.selection = TextSelection(
                                  baseOffset: 0,
                                  extentOffset: _textController.text.length,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 20),
                              tooltip: 'Copy Text',
                              onPressed: _copyTextToClipboard,
                            ),
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 20),
                              tooltip: 'Clear',
                              onPressed: () {
                                setState(() {
                                  _textController.clear();
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                _txtSaved ? Icons.check_circle : Icons.save_alt_rounded,
                                size: 20,
                                color: _txtSaved ? Colors.green : null,
                              ),
                              tooltip: 'Save as .txt',
                              onPressed: _saveAsTxtDocument,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: surfaceBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: TextField(
                        controller: _textController,
                        maxLines: null,
                        style: TextStyle(
                          fontSize: 13,
                          color: primaryText,
                          height: 1.4,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _copyTextToClipboard,
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Copy Text'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        if (AppConfig.isAiFeatureEnabled) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AiDocumentAssistantView(
                                      initialText: _textController.text,
                                      initialDocument: widget.document,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF7046A8)),
                              label: const Text('AI Assistant'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _txtSaved ? null : _saveAsTxtDocument,
                            icon: Icon(
                              _txtSaved ? Icons.check : Icons.save_rounded,
                              size: 16,
                            ),
                            label: Text(_txtSaved ? 'Saved' : 'Save .TXT'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConfig.isAiFeatureEnabled ? null : const Color(0xFF7046A8),
                              foregroundColor: AppConfig.isAiFeatureEnabled ? null : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Return to Scanner / New Scan
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SmartScannerView(),
                  ),
                );
              },
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text(
                'Start New Scan',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
