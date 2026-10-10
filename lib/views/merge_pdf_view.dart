import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/ad_mob_service.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:all_documents_reader/widgets/generated_pdf_success_sheet.dart';

/// Screen allowing users to select multiple PDFs, reorder them, and merge into a single PDF
class MergePdfView extends StatefulWidget {
  const MergePdfView({super.key});

  @override
  State<MergePdfView> createState() => _MergePdfViewState();
}

class _MergePdfViewState extends State<MergePdfView> {
  final List<InspectedPdfInfo> _selectedPdfs = [];
  final Set<String> _selectedPaths = {};
  final TextEditingController _fileNameController = TextEditingController();

  bool _isMerging = false;
  int _progressCurrent = 0;
  int _progressTotal = 0;
  bool _isAdvancedIndex = false;

  bool get isAdvancedIndexUnlocked =>
      AdMobService.instance.isPerkUnlocked('merge_pdf_advanced_index');

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  Future<void> _pickPdfs() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result.isEmpty) return;

      int duplicateCount = 0;
      final List<InspectedPdfInfo> newPdfs = [];

      for (final file in result) {
        if (file.path == null) continue;
        final path = file.path!;

        if (_selectedPaths.contains(path)) {
          duplicateCount++;
          continue;
        }

        try {
          final info = await PdfOperationsService.instance.inspectPdf(path);
          _selectedPaths.add(path);
          newPdfs.add(info);
        } catch (_) {
          // Skip invalid/unreadable PDFs
        }
      }

      if (newPdfs.isNotEmpty) {
        setState(() {
          _selectedPdfs.addAll(newPdfs);
        });
      }

      if (duplicateCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              '$duplicateCount duplicate ${duplicateCount == 1 ? "PDF was" : "PDFs were"} skipped',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Error selecting PDF files: $e'),
        ),
      );
    }
  }

  void _removePdfAt(int index) {
    setState(() {
      final removed = _selectedPdfs.removeAt(index);
      _selectedPaths.remove(removed.path);
    });
  }

  Future<void> _mergePdfs() async {
    if (_selectedPdfs.length < 2 || _isMerging) return;

    if (_isAdvancedIndex && !isAdvancedIndexUnlocked) {
      final unlocked = await AdMobService.instance.showRewardedAdPrompt(
        context,
        title: 'Unlock Document Indexing',
        description: 'Watch a short ad to unlock this advanced option',
        perkKey: 'merge_pdf_advanced_index',
        actionButtonLabel: 'Watch Ad',
      );
      if (!unlocked) {
        setState(() {
          _isAdvancedIndex = false;
        });
        return;
      }
    }

    setState(() {
      _isMerging = true;
      _progressCurrent = 0;
      _progressTotal = _selectedPdfs.length;
    });

    try {
      final result = await PdfOperationsService.instance.mergePdfs(
        pdfPaths: _selectedPdfs.map((p) => p.path).toList(),
        customFileName: _fileNameController.text.trim(),
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _progressCurrent = current;
              _progressTotal = total;
            });
          }
        },
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
        _isMerging = false;
        _selectedPdfs.clear();
        _selectedPaths.clear();
        _fileNameController.clear();
      });

      _showSuccessDialog(newDoc, result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isMerging = false;
      });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Merge Failed'),
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

  void _showSuccessDialog(DocumentsModel document, PdfOperationResult result) {
    GeneratedPdfSuccessSheet.show(
      context: context,
      document: document,
      file: result.file,
      subtitle: '${result.pageCount} pages • ${result.formattedSize}',
      onDone: () async {
        await AdMobService.instance.showInterstitialAd(
          context: context,
          triggerReason: 'merge_pdf_done',
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
        title: const Text('Merge PDF'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedPdfs.isNotEmpty && !_isMerging)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear All',
              onPressed: () {
                setState(() {
                  _selectedPdfs.clear();
                  _selectedPaths.clear();
                });
              },
            ),
        ],
      ),
      body: _selectedPdfs.isEmpty
          ? _buildEmptyState(isDark, primaryText, secondaryText)
          : _buildListState(isDark, primaryText, secondaryText, cardBg),
      bottomNavigationBar: _selectedPdfs.isNotEmpty
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
                color: const Color(0xFF7B1FA2).withValues(alpha: isDark ? 0.25 : 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.call_merge_rounded,
                size: 52,
                color: Color(0xFF7B1FA2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select PDFs to Merge',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose two or more PDF files to combine into a single organized document. You can reorder pages before merging.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: secondaryText, height: 1.4),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B1FA2),
                  foregroundColor: Colors.white,
                ),
                onPressed: _pickPdfs,
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text(
                  'Select PDF Files',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListState(
    bool isDark,
    Color primaryText,
    Color secondaryText,
    Color cardBg,
  ) {
    final totalPages = _selectedPdfs.fold<int>(0, (sum, p) => sum + p.pageCount);

    return Column(
      children: [
        // Top Toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_selectedPdfs.length} PDFs • $totalPages Total Pages',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                  Text(
                    'Drag handle to adjust merge order',
                    style: TextStyle(fontSize: 12, color: secondaryText),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _isMerging ? null : _pickPdfs,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add PDF', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),

        // Custom File Name
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: TextField(
              controller: _fileNameController,
              enabled: !_isMerging,
              decoration: const InputDecoration(
                hintText: 'Merged File Name (Optional)',
                prefixIcon: Icon(Icons.edit_note_rounded, color: Color(0xFF7B1FA2)),
                suffixText: '.pdf',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ),

        // Reorderable PDF List
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _selectedPdfs.length,
            // ignore: deprecated_member_use
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) newIndex -= 1;
                final item = _selectedPdfs.removeAt(oldIndex);
                _selectedPdfs.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final pdf = _selectedPdfs[index];
              return Card(
                key: ValueKey(pdf.path),
                color: cardBg,
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(10),
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
                              pdf.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: primaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${pdf.pageCount} ${pdf.pageCount == 1 ? "page" : "pages"} • ${pdf.formattedSize}',
                              style: TextStyle(fontSize: 11.5, color: secondaryText),
                            ),
                          ],
                        ),
                      ),
                      if (!_isMerging)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: Colors.redAccent),
                          tooltip: 'Remove',
                          onPressed: () => _removePdfAt(index),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isMerging && _selectedPdfs.length >= 2) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1729) : const Color(0xFFF9F7FD),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF7B1FA2).withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bookmarks_outlined,
                      color: Color(0xFF7B1FA2),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Mode:',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    // Standard
                    InkWell(
                      onTap: () => setState(() => _isAdvancedIndex = false),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: !_isAdvancedIndex
                              ? const Color(0xFF7B1FA2).withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Standard',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: !_isAdvancedIndex ? FontWeight.bold : FontWeight.normal,
                            color: !_isAdvancedIndex
                                ? const Color(0xFF7B1FA2)
                                : (isDark ? Colors.grey[400] : Colors.grey[700]),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Advanced Index
                    InkWell(
                      onTap: () async {
                        if (isAdvancedIndexUnlocked) {
                          setState(() => _isAdvancedIndex = true);
                        } else {
                          final unlocked = await AdMobService.instance.showRewardedAdPrompt(
                            context,
                            title: 'Unlock Document Indexing',
                            description: 'Watch a short ad to unlock this advanced option',
                            perkKey: 'merge_pdf_advanced_index',
                            actionButtonLabel: 'Watch Ad',
                          );
                          if (unlocked && mounted) {
                            setState(() => _isAdvancedIndex = true);
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isAdvancedIndex
                              ? const Color(0xFF7B1FA2)
                              : (isDark ? const Color(0xFF2C223A) : const Color(0xFFEDE5F8)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Indexing',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: _isAdvancedIndex ? Colors.white : const Color(0xFF7B1FA2),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isAdvancedIndexUnlocked ? '✨' : '🎬',
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
            if (_isMerging) ...[
              LinearProgressIndicator(
                value: _progressTotal > 0 ? _progressCurrent / _progressTotal : null,
                backgroundColor: isDark ? const Color(0xFF382F45) : const Color(0xFFEDE7F6),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7B1FA2)),
              ),
              const SizedBox(height: 8),
              Text(
                'Merging PDF $_progressCurrent of $_progressTotal...',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B1FA2),
                  foregroundColor: Colors.white,
                ),
                onPressed: _selectedPdfs.length < 2 || _isMerging ? null : _mergePdfs,
                icon: _isMerging
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.call_merge_rounded),
                label: Text(
                  _isMerging
                      ? 'Merging PDFs...'
                      : 'Merge ${_selectedPdfs.length} PDFs',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
