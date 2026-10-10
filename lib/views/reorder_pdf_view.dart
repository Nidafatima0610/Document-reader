import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/ad_mob_service.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:all_documents_reader/widgets/generated_pdf_success_sheet.dart';

/// Screen allowing users to visually reorder pages of a PDF and delete unwanted pages
class ReorderPdfView extends StatefulWidget {
  const ReorderPdfView({super.key});

  @override
  State<ReorderPdfView> createState() => _ReorderPdfViewState();
}

class _ReorderPdfViewState extends State<ReorderPdfView> {
  InspectedPdfInfo? _pdfInfo;
  final List<int> _pageOrder = []; // 1-based page numbers
  final TextEditingController _fileNameController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
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
        _pageOrder.clear();
        for (int i = 1; i <= info.pageCount; i++) {
          _pageOrder.add(i);
        }
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

  void _removePageAt(int index) {
    if (_pageOrder.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: const Text('A document must have at least 1 page.'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    setState(() {
      _pageOrder.removeAt(index);
    });
  }

  bool get isBatchInvertUnlocked =>
      AdMobService.instance.isPerkUnlocked('reorder_pdf_batch_invert');

  Future<void> _handleBatchInvert() async {
    if (_pageOrder.length <= 1) return;

    if (isBatchInvertUnlocked) {
      setState(() {
        final reversed = _pageOrder.reversed.toList();
        _pageOrder.clear();
        _pageOrder.addAll(reversed);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Page sequence inverted!'),
        ),
      );
      return;
    }

    final unlocked = await AdMobService.instance.showRewardedAdPrompt(
      context,
      title: 'Unlock Reverse Sequence',
      description: 'Watch a short ad to invert all pages sequence instantly.',
      perkKey: 'reorder_pdf_batch_invert',
    );

    if (unlocked && mounted) {
      setState(() {
        final reversed = _pageOrder.reversed.toList();
        _pageOrder.clear();
        _pageOrder.addAll(reversed);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Unlocked & page sequence inverted!'),
        ),
      );
    } else if (!unlocked && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Standard manual reordering remains free.'),
        ),
      );
    }
  }

  Future<void> _saveReorderedPdf() async {
    if (_pdfInfo == null || _pageOrder.isEmpty || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final result = await PdfOperationsService.instance.reorderPdfPages(
        pdfPath: _pdfInfo!.path,
        newPageOrder: _pageOrder,
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
        _isSaving = false;
      });

      _showSuccessDialog(newDoc, result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Failed to reorder PDF: $e'),
        ),
      );
    }
  }

  void _showSuccessDialog(DocumentsModel document, PdfOperationResult result) {
    GeneratedPdfSuccessSheet.show(
      context: context,
      document: document,
      file: result.file,
      subtitle: '${result.pageCount} pages • ${result.formattedSize}',
      onDone: () async {
        await AdMobService.instance.showInterstitialAd(
          context: context,
          triggerReason: 'reorder_pdf_done',
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
        title: const Text('Reorder PDF Pages'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_pdfInfo != null && !_isSaving)
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Change PDF',
              onPressed: _pickPdf,
            ),
        ],
      ),
      body: _pdfInfo == null
          ? _buildEmptyState(isDark, primaryText, secondaryText)
          : _buildReorderView(isDark, primaryText, secondaryText, cardBg),
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
                color: const Color(0xFF5D4037).withValues(alpha: isDark ? 0.25 : 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.reorder_rounded,
                size: 52,
                color: Color(0xFF5D4037),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select PDF to Reorder',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Drag and drop pages to rearrange their order, or remove unwanted pages before saving.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: secondaryText, height: 1.4),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D4037),
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

  Widget _buildReorderView(
    bool isDark,
    Color primaryText,
    Color secondaryText,
    Color cardBg,
  ) {
    return Column(
      children: [
        // File Info Card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Card(
            color: cardBg,
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFFD32F2F),
                    size: 28,
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
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                        Text(
                          '${_pageOrder.length} pages in new document • ${_pdfInfo!.formattedSize}',
                          style: TextStyle(fontSize: 11.5, color: secondaryText),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _isSaving ? null : _pickPdf,
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Quick Batch Tools (Rewarded unlock)
        _buildQuickToolsCard(isDark, cardBg, primaryText, secondaryText),

        // Reorder instruction
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hold & drag handle to change page order',
                style: TextStyle(fontSize: 12, color: secondaryText),
              ),
              Text(
                '${_pageOrder.length} pages',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037),
                ),
              ),
            ],
          ),
        ),

        // Reorderable Pages List
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: _pageOrder.length,
            // ignore: deprecated_member_use
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) newIndex -= 1;
                final item = _pageOrder.removeAt(oldIndex);
                _pageOrder.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final originalPageNum = _pageOrder[index];
              return Card(
                key: ValueKey('page_pos_${index}_orig_$originalPageNum'),
                color: cardBg,
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.drag_handle_rounded,
                            color: isDark ? Colors.grey[500] : Colors.grey[400],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF382F45) : const Color(0xFFEFEBE9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Pos ${index + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5D4037),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Original Page $originalPageNum',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_isSaving)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: Colors.redAccent),
                          tooltip: 'Remove Page',
                          onPressed: () => _removePageAt(index),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickToolsCard(
    bool isDark,
    Color cardBg,
    Color primaryText,
    Color secondaryText,
  ) {
    final unlocked = isBatchInvertUnlocked;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE0E0E0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.swap_vert_rounded, size: 18, color: Color(0xFF5D4037)),
                    const SizedBox(width: 6),
                    Text(
                      'Batch Invert Sequence',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  unlocked
                      ? 'Reverses entire page sequence automatically'
                      : 'Watch ad to invert all pages instantly',
                  style: TextStyle(fontSize: 11, color: secondaryText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _isSaving ? null : _handleBatchInvert,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: unlocked
                    ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
                    : const Color(0xFF5D4037).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: unlocked
                      ? const Color(0xFF2E7D32).withValues(alpha: 0.4)
                      : const Color(0xFF5D4037).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    unlocked ? Icons.check_circle_rounded : Icons.play_circle_outline_rounded,
                    size: 14,
                    color: unlocked ? const Color(0xFF2E7D32) : const Color(0xFF5D4037),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unlocked ? 'Invert (Unlocked)' : 'Invert Order',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: unlocked ? const Color(0xFF2E7D32) : const Color(0xFF5D4037),
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
              backgroundColor: const Color(0xFF5D4037),
              foregroundColor: Colors.white,
            ),
            onPressed: _isSaving || _pageOrder.isEmpty ? null : _saveReorderedPdf,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(
              _isSaving
                  ? 'Saving Reordered PDF...'
                  : 'Save New Order (${_pageOrder.length} pages)',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
