import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/ad_mob_service.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:all_documents_reader/views/pdf_viewer_screen.dart';

/// Screen allowing users to permanently rotate pages of a PDF document
class RotatePdfView extends StatefulWidget {
  const RotatePdfView({super.key});

  @override
  State<RotatePdfView> createState() => _RotatePdfViewState();
}

class _RotatePdfViewState extends State<RotatePdfView> {
  InspectedPdfInfo? _pdfInfo;
  PdfPageRotateAngle _selectedAngle = PdfPageRotateAngle.rotateAngle90;
  bool _isAllPages = true;
  final Set<int> _selectedPages = {};
  final TextEditingController _fileNameController = TextEditingController();

  bool _isRotating = false;

  bool get isSelectiveRotateUnlocked =>
      AdMobService.instance.isPerkUnlocked('rotate_pdf_selective_pages');

  Future<void> _onScopeChanged(bool allPages) async {
    if (allPages) {
      setState(() => _isAllPages = true);
      return;
    }

    if (isSelectiveRotateUnlocked) {
      setState(() => _isAllPages = false);
      return;
    }

    final unlocked = await AdMobService.instance.showRewardedAdPrompt(
      context,
      title: 'Unlock Selective Page Rotation',
      description:
          'Watch a short ad to selectively rotate specific individual pages while leaving other pages in original orientation.',
      perkKey: 'rotate_pdf_selective_pages',
      actionButtonLabel: 'Watch Ad',
      cancelButtonLabel: 'Not Now',
      unlockNotice:
          'All-pages rotation is 100% free with no ads. Watching 1 ad unlocks selective custom page rotation for the session.',
    );

    if (mounted) {
      setState(() {
        _isAllPages = !unlocked;
      });
    }
  }

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
        _isAllPages = true;
        _selectedPages.clear();
        for (int i = 1; i <= info.pageCount; i++) {
          _selectedPages.add(i);
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

  void _togglePage(int page) {
    setState(() {
      if (_selectedPages.contains(page)) {
        if (_selectedPages.length > 1) {
          _selectedPages.remove(page);
        }
      } else {
        _selectedPages.add(page);
      }
    });
  }

  Future<void> _rotatePdf() async {
    if (_pdfInfo == null || _isRotating) return;

    setState(() {
      _isRotating = true;
    });

    try {
      final targetPages = _isAllPages ? null : _selectedPages.toList();
      final result = await PdfOperationsService.instance.rotatePdf(
        pdfPath: _pdfInfo!.path,
        angle: _selectedAngle,
        targetPages: targetPages,
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
        _isRotating = false;
      });

      _showSuccessDialog(newDoc, result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRotating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Failed to rotate PDF: $e'),
        ),
      );
    }
  }

  void _showSuccessDialog(DocumentsModel document, PdfOperationResult result) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF2E7D32),
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'PDF Rotated Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2D2435),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Orientation updated and saved to your Documents list.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2536) : const Color(0xFFF3EDF9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFFD32F2F),
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${result.pageCount} pages • ${result.formattedSize}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await AdMobService.instance.showInterstitialAd(
                context: context,
                triggerReason: 'rotate_pdf_done',
              );
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Done'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Open PDF'),
            onPressed: () {
              Navigator.pop(dialogContext);
              DocumentsStorageService.instance.recordDocumentOpened(document);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PdfViewerScreen(
                    file: result.file,
                    title: document.name,
                    document: document,
                  ),
                ),
              );
            },
          ),
        ],
      ),
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
        title: const Text('Rotate PDF'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_pdfInfo != null && !_isRotating)
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
                color: const Color(0xFFE65100).withValues(alpha: isDark ? 0.25 : 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.rotate_right_rounded,
                size: 52,
                color: Color(0xFFE65100),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select PDF to Rotate',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Adjust the orientation of all pages or selectively picked pages by 90°, 180°, or 270° clockwise.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: secondaryText, height: 1.4),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
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
                  onPressed: _isRotating ? null : _pickPdf,
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Rotation Angle Options
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
                  'Rotation Angle',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 10),
                SegmentedButton<PdfPageRotateAngle>(
                  segments: const [
                    ButtonSegment(
                      value: PdfPageRotateAngle.rotateAngle90,
                      label: Text('90° CW'),
                      icon: Icon(Icons.rotate_right_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: PdfPageRotateAngle.rotateAngle180,
                      label: Text('180°'),
                      icon: Icon(Icons.replay_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: PdfPageRotateAngle.rotateAngle270,
                      label: Text('270° CW'),
                      icon: Icon(Icons.rotate_left_rounded, size: 18),
                    ),
                  ],
                  selected: {_selectedAngle},
                  onSelectionChanged: _isRotating
                      ? null
                      : (set) => setState(() => _selectedAngle = set.first),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Scope Selection
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
                  'Pages to Rotate',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 10),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text('All Pages (${_pdfInfo!.pageCount}) • Free'),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(
                        isSelectiveRotateUnlocked
                            ? 'Specific Pages • Unlocked'
                            : 'Specific Pages • Watch Ad',
                      ),
                      icon: Icon(
                        isSelectiveRotateUnlocked
                            ? Icons.check_circle_rounded
                            : Icons.play_circle_outline_rounded,
                        size: 16,
                        color: isSelectiveRotateUnlocked
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFE65100),
                      ),
                    ),
                  ],
                  selected: {_isAllPages},
                  onSelectionChanged: _isRotating
                      ? null
                      : (set) => _onScopeChanged(set.first),
                ),
                if (!_isAllPages) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(_pdfInfo!.pageCount, (index) {
                      final pNum = index + 1;
                      final isSelected = _selectedPages.contains(pNum);
                      return FilterChip(
                        label: Text('Page $pNum'),
                        selected: isSelected,
                        selectedColor: const Color(0xFFE65100).withValues(alpha: 0.2),
                        checkmarkColor: const Color(0xFFE65100),
                        onSelected: _isRotating ? null : (_) => _togglePage(pNum),
                      );
                    }),
                  ),
                ],
              ],
            ),
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
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
            ),
            onPressed: _isRotating ? null : _rotatePdf,
            icon: _isRotating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.rotate_right_rounded),
            label: Text(
              _isRotating ? 'Rotating PDF...' : 'Rotate and Save PDF',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
