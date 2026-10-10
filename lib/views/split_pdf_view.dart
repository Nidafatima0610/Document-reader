import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/ad_mob_service.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:all_documents_reader/widgets/generated_pdf_success_sheet.dart';

/// Screen allowing users to select a PDF and extract specific pages into a new PDF
class SplitPdfView extends StatefulWidget {
  const SplitPdfView({super.key});

  @override
  State<SplitPdfView> createState() => _SplitPdfViewState();
}

class _SplitPdfViewState extends State<SplitPdfView> {
  InspectedPdfInfo? _pdfInfo;
  final Set<int> _selectedPages = {};
  final TextEditingController _rangeController = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController();

  bool _isSplitting = false;
  bool _extractAsSeparateFiles = false;

  bool get isIndividualSplitUnlocked =>
      AdMobService.instance.isPerkUnlocked('split_pdf_individual_pages');

  void _selectStandardCombined() {
    setState(() {
      _extractAsSeparateFiles = false;
    });
  }

  Future<bool> _selectIndividualSplit() async {
    if (isIndividualSplitUnlocked) {
      setState(() {
        _extractAsSeparateFiles = true;
      });
      return true;
    }

    final unlocked = await AdMobService.instance.showRewardedAdPrompt(
      context,
      title: 'Unlock Separate File Extraction',
      description:
          'Watch a short ad to split each selected page into its own individual PDF document.',
      perkKey: 'split_pdf_individual_pages',
      actionButtonLabel: 'Watch Ad',
      cancelButtonLabel: 'Not Now',
      unlockNotice:
          'Standard extraction saves all selected pages into one PDF for free. Watching 1 ad unlocks separate individual PDFs.',
    );

    if (mounted) {
      setState(() {
        _extractAsSeparateFiles = unlocked;
      });
    }
    return unlocked;
  }

  @override
  void dispose() {
    _rangeController.dispose();
    _fileNameController.dispose();
    super.dispose();
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
        _selectedPages.clear();
        // default select first page
        _selectedPages.add(1);
        _rangeController.text = '1';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Cannot read PDF: $e'),
        ),
      );
    }
  }

  void _onRangeTextChanged(String text) {
    if (_pdfInfo == null) return;
    final parsed = PdfOperationsService.instance.parsePageRange(
      text,
      _pdfInfo!.pageCount,
    );
    setState(() {
      _selectedPages.clear();
      _selectedPages.addAll(parsed);
    });
  }

  void _togglePage(int page) {
    setState(() {
      if (_selectedPages.contains(page)) {
        if (_selectedPages.length > 1) {
          _selectedPages.remove(page);
        }
      } else {
        _selectedPages.add(page);
      }
      final sorted = _selectedPages.toList()..sort();
      _rangeController.text = sorted.join(', ');
    });
  }

  Future<void> _splitPdf() async {
    if (_pdfInfo == null || _selectedPages.isEmpty || _isSplitting) return;

    setState(() {
      _isSplitting = true;
    });

    try {
      final pagesList = _selectedPages.toList()..sort();

      if (_extractAsSeparateFiles) {
        final baseName = _fileNameController.text.trim().isNotEmpty
            ? _fileNameController.text.trim()
            : _pdfInfo!.fileName
                .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
        int count = 0;
        DocumentsModel? lastDoc;
        PdfOperationResult? lastResult;

        for (final pNum in pagesList) {
          final res = await PdfOperationsService.instance.splitPdf(
            pdfPath: _pdfInfo!.path,
            pages: [pNum],
            customFileName: '${baseName}_Page_$pNum.pdf',
          );
          final doc = DocumentsModel(
            name: res.fileName,
            path: res.file.path,
            type: 'pdf',
            createdAt: DateTime.now(),
          );
          await DocumentsStorageService.instance.addDocument(doc);
          count++;
          lastDoc = doc;
          lastResult = res;
        }

        if (!mounted) return;
        setState(() {
          _isSplitting = false;
        });

        _showSuccessDialog(lastDoc!, lastResult!, totalCreated: count);
      } else {
        final result = await PdfOperationsService.instance.splitPdf(
          pdfPath: _pdfInfo!.path,
          pages: pagesList,
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
          _isSplitting = false;
        });

        _showSuccessDialog(newDoc, result, totalCreated: 1);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSplitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Failed to extract pages: $e'),
        ),
      );
    }
  }

  void _showSuccessDialog(
    DocumentsModel document,
    PdfOperationResult result, {
    int totalCreated = 1,
  }) {
    GeneratedPdfSuccessSheet.show(
      context: context,
      document: document,
      file: result.file,
      subtitle: totalCreated > 1
          ? '$totalCreated documents created • ${result.pageCount} pages • ${result.formattedSize}'
          : '${result.pageCount} ${result.pageCount == 1 ? "page" : "pages"} • ${result.formattedSize}',
      onDone: () async {
        await AdMobService.instance.showInterstitialAd(
          context: context,
          triggerReason: 'split_pdf_done',
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
    final primaryText = isDark ? Colors.white : const Color(0xFF2D2435);
    final secondaryText = isDark ? const Color(0xFFB0A9B8) : const Color(0xFF6C6374);
    final cardBg = isDark ? const Color(0xFF211C29) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split PDF'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_pdfInfo != null && !_isSplitting)
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Change PDF',
              onPressed: _pickPdf,
            ),
        ],
      ),
      body: _pdfInfo == null
          ? _buildEmptyState(isDark, primaryText, secondaryText)
          : _buildConfigView(isDark, primaryText, secondaryText, cardBg),
      bottomNavigationBar: _pdfInfo != null
          ? _buildBottomBar(isDark, cardBg)
          : null,
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
                color: const Color(0xFF0097A7).withValues(alpha: isDark ? 0.25 : 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.call_split_rounded,
                size: 52,
                color: Color(0xFF0097A7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select PDF to Split',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Extract specific pages or page ranges from an existing PDF into a brand-new PDF document.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: secondaryText, height: 1.4),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0097A7),
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

  Widget _buildConfigView(
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
                  onPressed: _isSplitting ? null : _pickPdf,
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Range Input Card
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
                  'Select Pages to Extract',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _rangeController,
                  enabled: !_isSplitting,
                  onChanged: _onRangeTextChanged,
                  decoration: InputDecoration(
                    labelText: 'Page Range',
                    hintText: 'e.g. 1-3, 5',
                    prefixIcon: const Icon(Icons.filter_list_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tap pages to toggle:',
                      style: TextStyle(fontSize: 12, color: secondaryText),
                    ),
                    Text(
                      '${_selectedPages.length} of ${_pdfInfo!.pageCount} pages',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0097A7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Page chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(_pdfInfo!.pageCount, (index) {
                    final pNum = index + 1;
                    final isSelected = _selectedPages.contains(pNum);
                    return FilterChip(
                      label: Text('Page $pNum'),
                      selected: isSelected,
                      selectedColor: const Color(0xFF0097A7).withValues(alpha: 0.2),
                      checkmarkColor: const Color(0xFF0097A7),
                      onSelected: _isSplitting ? null : (_) => _togglePage(pNum),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Extraction Format Mode Card
        _buildExtractionModeCard(isDark, cardBg, primaryText, secondaryText),

        const SizedBox(height: 12),

        // Output file name
        Card(
          color: cardBg,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _fileNameController,
              enabled: !_isSplitting,
              decoration: InputDecoration(
                hintText: 'Extracted PDF Name (Optional)',
                suffixText: '.pdf',
                prefixIcon: const Icon(
                  Icons.edit_note_rounded,
                  color: Color(0xFF0097A7),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExtractionModeCard(
    bool isDark,
    Color cardBg,
    Color primaryText,
    Color secondaryText,
  ) {
    final bool unlocked = isIndividualSplitUnlocked;

    return Container(
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
                  color: const Color(0xFF0097A7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: Color(0xFF0097A7),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Extraction Format',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Option 1: Combined Single PDF — Free
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isSplitting ? null : _selectStandardCombined,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: !_extractAsSeparateFiles
                    ? (isDark ? const Color(0xFF1E2D30) : const Color(0xFFE0F7FA))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !_extractAsSeparateFiles
                      ? const Color(0xFF0097A7)
                      : (isDark ? Colors.white12 : Colors.black12),
                  width: !_extractAsSeparateFiles ? 1.8 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    !_extractAsSeparateFiles
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: !_extractAsSeparateFiles ? const Color(0xFF0097A7) : secondaryText,
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
                                'Single Combined PDF',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: primaryText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
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
                          'Combines all picked pages into one clean PDF • 100% Free',
                          style: TextStyle(fontSize: 11.5, color: secondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Option 2: Individual Page PDFs — Watch Ad to Unlock
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isSplitting ? null : () => _selectIndividualSplit(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _extractAsSeparateFiles
                    ? (isDark ? const Color(0xFF1E2D30) : const Color(0xFFE0F7FA))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _extractAsSeparateFiles
                      ? const Color(0xFF0097A7)
                      : (isDark ? Colors.white12 : Colors.black12),
                  width: _extractAsSeparateFiles ? 1.8 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _extractAsSeparateFiles
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: _extractAsSeparateFiles ? const Color(0xFF0097A7) : secondaryText,
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
                                'Separate Individual PDFs',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: primaryText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: unlocked
                                    ? const Color(0xFF2E7D32).withValues(alpha: 0.15)
                                    : const Color(0xFF7046A8).withValues(alpha: 0.15),
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
                              ? 'Splits each page into its own PDF • Session unlocked'
                              : 'Splits each page into its own PDF • Watch 1 ad to unlock',
                          style: TextStyle(fontSize: 11.5, color: secondaryText),
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

  Widget _buildBottomBar(bool isDark, Color cardBg) {
    final count = _selectedPages.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0097A7),
              foregroundColor: Colors.white,
            ),
            onPressed: _isSplitting || count == 0 ? null : _splitPdf,
            icon: _isSplitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.call_split_rounded),
            label: Text(
              _isSplitting
                  ? 'Extracting Pages...'
                  : _extractAsSeparateFiles
                      ? 'Extract $count Separate PDFs'
                      : 'Extract $count ${count == 1 ? "Page" : "Pages"}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
