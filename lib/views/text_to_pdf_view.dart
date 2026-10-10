import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/ad_mob_service.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:all_documents_reader/services/text_to_pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:all_documents_reader/widgets/generated_pdf_success_sheet.dart';

/// Screen allowing users to write/paste text notes and generate a multi-page PDF
class TextToPdfView extends StatefulWidget {
  const TextToPdfView({super.key});

  @override
  State<TextToPdfView> createState() => _TextToPdfViewState();
}

class _TextToPdfViewState extends State<TextToPdfView> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController();

  double _fontSize = 12.0;
  bool _includeDate = true;
  bool _isGenerating = false;
  bool _isExecutiveLayout = false;

  bool get isExecutiveUnlocked =>
      AdMobService.instance.isPerkUnlocked('text_to_pdf_executive');

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  int get _wordCount {
    final text = _contentController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  Future<void> _generatePdf() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: const Text('Please enter some text before generating PDF.'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (_isExecutiveLayout && !isExecutiveUnlocked) {
      final unlocked = await AdMobService.instance.showRewardedAdPrompt(
        context,
        title: 'Unlock Executive Styling',
        description: 'Watch a short ad to unlock this advanced option',
        perkKey: 'text_to_pdf_executive',
        actionButtonLabel: 'Watch Ad',
      );
      if (!unlocked) {
        setState(() {
          _isExecutiveLayout = false;
        });
        return;
      }
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final result = await TextToPdfService.instance.generatePdfFromText(
        text: content,
        options: TextToPdfOptions(
          title: _titleController.text.trim(),
          fontSize: _fontSize,
          includeDate: _includeDate,
          margin: _isExecutiveLayout ? 48.0 : 36.0,
        ),
        customFileName: _fileNameController.text.trim(),
      );

      final newDoc = DocumentsModel(
        name: result.fileName,
        path: result.file.path,
        type: 'pdf',
        createdAt: DateTime.now(),
      );
      await DocumentsStorageService.instance.addDocument(newDoc);

      if (!mounted) return;
      setState(() {
        _isGenerating = false;
      });

      _showSuccessDialog(newDoc, result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
      });
      _showErrorDialog('Failed to create PDF', e.toString());
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(DocumentsModel document, PdfOperationResult result) {
    GeneratedPdfSuccessSheet.show(
      context: context,
      document: document,
      file: result.file,
      subtitle: '${result.pageCount} ${result.pageCount == 1 ? "page" : "pages"} • ${result.formattedSize}',
      onDone: () async {
        await AdMobService.instance.showInterstitialAd(
          context: context,
          triggerReason: 'text_to_pdf_done',
        );
        if (mounted) {
          Navigator.pop(context);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF211C29) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Text to PDF'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_contentController.text.isNotEmpty && !_isGenerating)
            IconButton(
              icon: const Icon(Icons.clear_all_rounded),
              tooltip: 'Clear All',
              onPressed: () {
                setState(() {
                  _titleController.clear();
                  _contentController.clear();
                  _fileNameController.clear();
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document Title Card
            Card(
              color: cardBg,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: TextField(
                  controller: _titleController,
                  enabled: !_isGenerating,
                  decoration: const InputDecoration(
                    hintText: 'Document Title (Optional)',
                    border: InputBorder.none,
                    icon: Icon(Icons.title_rounded, color: Color(0xFF7046A8)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Content Input Card
            Card(
              color: cardBg,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _contentController,
                      enabled: !_isGenerating,
                      maxLines: 12,
                      minLines: 8,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Type or paste your document text here...',
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_wordCount words • ${_contentController.text.length} chars',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        if (_contentController.text.isNotEmpty)
                          TextButton.icon(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Clear', style: TextStyle(fontSize: 12)),
                            onPressed: _isGenerating
                                ? null
                                : () => setState(() => _contentController.clear()),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Formatting & Custom File Name Card
            Card(
              color: cardBg,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PDF Options',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Font Size',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _fontSize == 10.0
                                  ? 'Small (10 pt)'
                                  : (_fontSize == 12.0
                                      ? 'Medium (12 pt)'
                                      : 'Large (14 pt)'),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7046A8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<double>(
                            showSelectedIcon: false,
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            segments: const [
                              ButtonSegment(
                                value: 10.0,
                                label: Text('Small'),
                              ),
                              ButtonSegment(
                                value: 12.0,
                                label: Text('Medium'),
                              ),
                              ButtonSegment(
                                value: 14.0,
                                label: Text('Large'),
                              ),
                            ],
                            selected: {_fontSize},
                            onSelectionChanged: _isGenerating
                                ? null
                                : (set) => setState(() => _fontSize = set.first),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Include Date in Header'),
                      value: _includeDate,
                      onChanged: _isGenerating
                          ? null
                          : (val) => setState(() => _includeDate = val),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _fileNameController,
                      enabled: !_isGenerating,
                      decoration: InputDecoration(
                        hintText: 'Output File Name (e.g. MyMeetingNotes)',
                        suffixText: '.pdf',
                        prefixIcon: const Icon(
                          Icons.edit_note_rounded,
                          color: Color(0xFF7046A8),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Layout Selector
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1729) : const Color(0xFFF9F7FD),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF7046A8).withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.style_outlined,
                            color: Color(0xFF7046A8),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Layout:',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          // Standard
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isExecutiveLayout = false;
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: !_isExecutiveLayout
                                    ? const Color(0xFF7046A8).withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Standard',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: !_isExecutiveLayout
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: !_isExecutiveLayout
                                      ? const Color(0xFF7046A8)
                                      : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Executive
                          InkWell(
                            onTap: () async {
                              if (isExecutiveUnlocked) {
                                setState(() {
                                  _isExecutiveLayout = true;
                                });
                              } else {
                                final unlocked =
                                    await AdMobService.instance.showRewardedAdPrompt(
                                  context,
                                  title: 'Unlock Executive Styling',
                                  description:
                                      'Watch a short ad to unlock this advanced option',
                                  perkKey: 'text_to_pdf_executive',
                                  actionButtonLabel: 'Watch Ad',
                                );
                                if (unlocked && mounted) {
                                  setState(() {
                                    _isExecutiveLayout = true;
                                  });
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _isExecutiveLayout
                                    ? const Color(0xFF7046A8)
                                    : (isDark
                                        ? const Color(0xFF2C223A)
                                        : const Color(0xFFEDE5F8)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Executive',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: _isExecutiveLayout
                                          ? Colors.white
                                          : const Color(0xFF7046A8),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isExecutiveUnlocked ? '✨' : '🎬',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generatePdf,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded),
                label: Text(
                  _isGenerating ? 'Generating PDF...' : 'Convert to PDF',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
