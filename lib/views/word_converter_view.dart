import 'package:all_documents_reader/views/images_to_pdf_view.dart';
import 'package:all_documents_reader/views/pdf_to_text_view.dart';
import 'package:all_documents_reader/views/text_to_pdf_view.dart';
import 'package:flutter/material.dart';

enum WordConversionMode {
  pdfToWord,
  wordToPdf,
}

/// Information and feasibility screen for Word converters with zero fake buttons
class WordConverterView extends StatelessWidget {
  final WordConversionMode mode;

  const WordConverterView({super.key, required this.mode});

  bool get isPdfToWord => mode == WordConversionMode.pdfToWord;

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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: isDark ? 0.25 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPdfToWord ? Icons.article_outlined : Icons.description_outlined,
                size: 44,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 18),
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
            const SizedBox(height: 22),

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
