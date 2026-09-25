import 'package:all_documents_reader/services/ad_mob_service.dart';
import 'package:all_documents_reader/services/ocr_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Screen allowing users to select a PDF, extract its textual content, and edit/copy/save
class PdfToTextView extends StatefulWidget {
  const PdfToTextView({super.key});

  @override
  State<PdfToTextView> createState() => _PdfToTextViewState();
}

class _PdfToTextViewState extends State<PdfToTextView> {
  InspectedPdfInfo? _pdfInfo;
  final TextEditingController _extractedTextController = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController();

  bool _isExtracting = false;
  bool _isScanned = false;
  bool _isSaving = false;
  bool _isStructuredExtraction = false;

  bool get isStructuredExtractionUnlocked =>
      AdMobService.instance.isPerkUnlocked('pdf_to_text_structured_extraction');

  void _selectStandardContinuous() {
    setState(() {
      _isStructuredExtraction = false;
    });
    _extractText();
  }

  Future<bool> _selectStructuredExtraction() async {
    if (isStructuredExtractionUnlocked) {
      setState(() {
        _isStructuredExtraction = true;
      });
      _extractText();
      return true;
    }

    final unlocked = await AdMobService.instance.showRewardedAdPrompt(
      context,
      title: 'Unlock Structured Extraction',
      description:
          'Watch a short ad to extract text with page boundaries, document metrics, and clean paragraph breaks.',
      perkKey: 'pdf_to_text_structured_extraction',
      actionButtonLabel: 'Watch Ad',
      cancelButtonLabel: 'Not Now',
      unlockNotice:
          'Continuous raw text extraction is 100% free with no ads. Watching 1 ad unlocks structured page-by-page extraction for the session.',
    );

    if (mounted) {
      setState(() {
        _isStructuredExtraction = unlocked;
      });
      if (unlocked) {
        _extractText();
      }
    }
    return unlocked;
  }

  @override
  void dispose() {
    _extractedTextController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  int get _wordCount {
    final text = _extractedTextController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result.isEmpty || result.first.path == null) {
        return;
      }

      final filePath = result.first.path!;
      final info = await PdfOperationsService.instance.inspectPdf(filePath);

      setState(() {
        _pdfInfo = info;
        _extractedTextController.clear();
        _isScanned = false;
      });

      _extractText();
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Cannot Read PDF'),
            ],
          ),
          content: Text('$e'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _extractText() async {
    if (_pdfInfo == null) return;

    setState(() {
      _isExtracting = true;
      _isScanned = false;
    });

    try {
      if (_isStructuredExtraction) {
        final buffer = StringBuffer();
        buffer.writeln('═══════════════════════════════════════');
        buffer.writeln('DOCUMENT: ${_pdfInfo!.fileName}');
        buffer.writeln('TOTAL PAGES: ${_pdfInfo!.pageCount}');
        buffer.writeln('SIZE: ${_pdfInfo!.formattedSize}');
        buffer.writeln('═══════════════════════════════════════\n');

        int extractedPages = 0;
        for (int i = 1; i <= _pdfInfo!.pageCount; i++) {
          final pageRes =
              await PdfOperationsService.instance.extractTextFromPdf(
            pdfPath: _pdfInfo!.path,
            startPage: i,
            endPage: i,
          );
          buffer.writeln('--- Page $i of ${_pdfInfo!.pageCount} ---');
          if (pageRes.text.trim().isNotEmpty) {
            buffer.writeln(pageRes.text.trim());
            extractedPages++;
          } else {
            buffer.writeln('[No text layer detected on this page]');
          }
          buffer.writeln();
        }

        final fullText = buffer.toString().trim();
        if (!mounted) return;

        setState(() {
          _isExtracting = false;
          _extractedTextController.text = fullText;
          _isScanned = extractedPages == 0;
        });
      } else {
        final result = await PdfOperationsService.instance.extractTextFromPdf(
          pdfPath: _pdfInfo!.path,
        );

        if (!mounted) return;

        setState(() {
          _isExtracting = false;
          _extractedTextController.text = result.text;
          _isScanned = result.isScannedOrEmpty;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Failed to extract text: $e'),
        ),
      );
    }
  }

  void _copyToClipboard() {
    final text = _extractedTextController.text;
    if (text.isEmpty) return;

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: const Row(
          children: [
            Icon(Icons.check_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Extracted text copied to clipboard!'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveAsDocument() async {
    final text = _extractedTextController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final doc = await OcrService.instance.saveExtractedTextAsDocument(
        text: text,
        customFileName: _fileNameController.text.trim().isNotEmpty
            ? _fileNameController.text.trim()
            : '${_pdfInfo?.fileName ?? "PDF"}_text',
      );

      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32)),
              SizedBox(width: 8),
              Text('Document Saved!'),
            ],
          ),
          content: Text('Saved "${doc.name}" to your Documents list.'),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await AdMobService.instance.showInterstitialAd(
                  context: context,
                  triggerReason: 'pdf_to_text_saved',
                );
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Failed to save document: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF2D2435);
    final secondaryText = isDark ? const Color(0xFFB0A9B8) : const Color(0xFF6C6374);
    final cardBg = isDark ? const Color(0xFF211C29) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF to Text'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_pdfInfo != null && !_isExtracting)
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Change PDF',
              onPressed: _pickPdf,
            ),
        ],
      ),
      body: _pdfInfo == null
          ? _buildEmptyState(isDark, primaryText, secondaryText)
          : _buildExtractView(isDark, primaryText, secondaryText, cardBg),
    );
  }

  Widget _buildEmptyState(bool isDark, Color primaryText, Color secondaryText) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFD35400).withValues(alpha: isDark ? 0.25 : 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.text_snippet_outlined,
                size: 52,
                color: Color(0xFFD35400),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Extract Text from PDF',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select any PDF document to extract its full text layer into editable, copyable text or save as a .txt file.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: secondaryText, height: 1.4),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD35400),
                  foregroundColor: Colors.white,
                ),
                onPressed: _pickPdf,
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text(
                  'Select PDF File',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtractView(
    bool isDark,
    Color primaryText,
    Color secondaryText,
    Color cardBg,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // File Info Card
        Card(
          color: cardBg,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFFD32F2F),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pdfInfo!.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_pdfInfo!.pageCount} pages • ${_pdfInfo!.formattedSize}',
                        style: TextStyle(fontSize: 12, color: secondaryText),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _isExtracting ? null : _pickPdf,
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
        ),
        _buildExtractionFormatCard(isDark, cardBg, primaryText, secondaryText),
        const SizedBox(height: 12),

        // Scanned Document Alert Banner
        if (_isScanned)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade700),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.amber.shade800),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scanned Document Detected',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This PDF appears to be a scanned document or consists of images without an embedded digital text layer. To extract text from scanned images, use the "Image to Text (OCR)" tool.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.amber.shade100 : Colors.black87,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        if (_isScanned) const SizedBox(height: 12),

        // Extracted Text Area Card
        Card(
          color: cardBg,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Extracted Text',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: primaryText,
                      ),
                    ),
                    if (!_isExtracting && _extractedTextController.text.isNotEmpty)
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 20),
                            tooltip: 'Copy to Clipboard',
                            onPressed: _copyToClipboard,
                          ),
                        ],
                      ),
                  ],
                ),
                const Divider(),
                if (_isExtracting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Extracting text from PDF pages...'),
                        ],
                      ),
                    ),
                  )
                else
                  TextField(
                    controller: _extractedTextController,
                    maxLines: 14,
                    minLines: 8,
                    decoration: const InputDecoration(
                      hintText: 'No text extracted yet.',
                      border: InputBorder.none,
                    ),
                  ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_wordCount words • ${_extractedTextController.text.length} chars',
                      style: TextStyle(fontSize: 12, color: secondaryText),
                    ),
                    if (!_isExtracting && _extractedTextController.text.isNotEmpty)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD35400),
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _isSaving ? null : _saveAsDocument,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded, size: 16),
                        label: const Text('Save as .txt', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExtractionFormatCard(
    bool isDark,
    Color cardBg,
    Color primaryText,
    Color secondaryText,
  ) {
    final bool unlocked = isStructuredExtractionUnlocked;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD35400).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.format_line_spacing_rounded,
                  size: 18,
                  color: Color(0xFFD35400),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Extraction Output Format',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Option 1: Standard Continuous Stream — Free
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isExtracting ? null : _selectStandardContinuous,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: !_isStructuredExtraction
                    ? (isDark ? const Color(0xFF2E231F) : const Color(0xFFFBE9E7))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !_isStructuredExtraction
                      ? const Color(0xFFD35400)
                      : (isDark ? Colors.white12 : Colors.black12),
                  width: !_isStructuredExtraction ? 1.8 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    !_isStructuredExtraction
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: !_isStructuredExtraction
                        ? const Color(0xFFD35400)
                        : secondaryText,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Continuous Raw Text',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: primaryText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Free',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Clean continuous text stream across all pages • 100% Free',
                          style:
                              TextStyle(fontSize: 11.5, color: secondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Option 2: Structured Page-by-Page — Watch Ad to Unlock
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isExtracting ? null : () => _selectStructuredExtraction(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isStructuredExtraction
                    ? (isDark ? const Color(0xFF2E231F) : const Color(0xFFFBE9E7))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isStructuredExtraction
                      ? const Color(0xFFD35400)
                      : (isDark ? Colors.white12 : Colors.black12),
                  width: _isStructuredExtraction ? 1.8 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isStructuredExtraction
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: _isStructuredExtraction
                        ? const Color(0xFFD35400)
                        : secondaryText,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Structured Page-by-Page',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: primaryText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: unlocked
                                    ? const Color(0xFF2E7D32)
                                        .withValues(alpha: 0.15)
                                    : const Color(0xFF7046A8)
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    unlocked
                                        ? Icons.check_circle_rounded
                                        : Icons.play_circle_outline_rounded,
                                    size: 12,
                                    color: unlocked
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFF7046A8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    unlocked ? 'Unlocked' : 'Watch Ad to Unlock',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: unlocked
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFF7046A8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          unlocked
                              ? 'Includes page headers, metrics & boundaries • Session unlocked'
                              : 'Includes page headers, metrics & boundaries • Watch 1 ad to unlock',
                          style:
                              TextStyle(fontSize: 11.5, color: secondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
