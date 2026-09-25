import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/ad_mob_service.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:all_documents_reader/views/pdf_viewer_screen.dart';

/// Screen allowing users to optimize and compress PDF document streams
class CompressPdfView extends StatefulWidget {
  const CompressPdfView({super.key});

  @override
  State<CompressPdfView> createState() => _CompressPdfViewState();
}

class _CompressPdfViewState extends State<CompressPdfView> {
  InspectedPdfInfo? _pdfInfo;
  final TextEditingController _fileNameController = TextEditingController();

  bool _isCompressing = false;
  bool _isDeepCompression = false;

  bool get isDeepUnlocked =>
      AdMobService.instance.isPerkUnlocked('deep_pdf_compression');

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
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

  Future<void> _compressPdf() async {
    if (_pdfInfo == null || _isCompressing) return;

    setState(() {
      _isCompressing = true;
    });

    try {
      final result = await PdfOperationsService.instance.compressPdf(
        pdfPath: _pdfInfo!.path,
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
        _isCompressing = false;
      });

      _showResultDialog(newDoc, result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCompressing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Compression failed: $e'),
        ),
      );
    }
  }

  void _showResultDialog(DocumentsModel document, PdfCompressionResult result) {
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
                color: (result.isReduced ? const Color(0xFF2E7D32) : Colors.orange)
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                result.isReduced ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                color: result.isReduced ? const Color(0xFF2E7D32) : Colors.orange,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              result.isReduced ? 'Optimization Complete!' : 'Already Maximally Compressed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2D2435),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              result.isReduced
                  ? 'File size reduced by ${result.savingsPercentage.toStringAsFixed(1)}% (${_formatBytes(result.bytesSaved)} saved).'
                  : 'This PDF already uses maximum stream deflation. No unreferenced objects were found to safely trim.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // Comparison box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2536) : const Color(0xFFF3EDF9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Original Size:'),
                      Text(
                        _formatBytes(result.originalSizeBytes),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Optimized Size:'),
                      Text(
                        _formatBytes(result.compressedSizeBytes),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: result.isReduced ? const Color(0xFF2E7D32) : null,
                        ),
                      ),
                    ],
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
                triggerReason: 'compress_pdf_done',
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
    final secondaryText =
        isDark ? const Color(0xFFB0A9B8) : const Color(0xFF6C6374);
    final cardBg = isDark ? const Color(0xFF211C29) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compress PDF'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_pdfInfo != null && !_isCompressing)
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Change PDF',
              onPressed: _pickPdf,
            ),
        ],
      ),
      body: _pdfInfo == null
          ? _buildEmptyState(isDark, primaryText, secondaryText)
          : _buildCompressView(isDark, primaryText, secondaryText, cardBg),
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
                color: const Color(0xFF2E7D32).withValues(alpha: isDark ? 0.25 : 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.compress_rounded,
                size: 52,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select PDF to Compress',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Optimize PDF streams and eliminate unreferenced revision objects to reduce file size while maintaining clarity.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: secondaryText, height: 1.4),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
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

  Widget _buildCompressView(
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
                  onPressed: _isCompressing ? null : _pickPdf,
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Compression Level Selector Card
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
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      color: Color(0xFF2E7D32),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Compression Level',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Standard option
                InkWell(
                  onTap: () {
                    setState(() {
                      _isDeepCompression = false;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: !_isDeepCompression
                          ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: !_isDeepCompression
                            ? const Color(0xFF2E7D32)
                            : Colors.grey.withValues(alpha: 0.3),
                        width: !_isDeepCompression ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          !_isDeepCompression
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: !_isDeepCompression
                              ? const Color(0xFF2E7D32)
                              : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Text(
                                    'Standard Stream Compression',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '• Free',
                                    style: TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Lossless Deflate re-encoding. Safe, fast, and 100% free.',
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
                ),
                const SizedBox(height: 10),
                // Deep compression option
                InkWell(
                  onTap: () async {
                    if (isDeepUnlocked) {
                      setState(() {
                        _isDeepCompression = true;
                      });
                    } else {
                      final unlocked =
                          await AdMobService.instance.showRewardedAdPrompt(
                        context,
                        title: 'Unlock Deep Compression',
                        description:
                            'Deep Stream Compression analyzes document streams and purges redundant revision objects to maximize size reduction.',
                        perkKey: 'deep_pdf_compression',
                        actionButtonLabel: 'Watch Ad',
                        unlockNotice:
                            'Watch a short Google test ad to unlock Deep Compression for this session. Standard compression is always 100% free.',
                        perkUnlockedMessage:
                            'Deep Stream Compression Unlocked!',
                      );
                      if (unlocked && mounted) {
                        setState(() {
                          _isDeepCompression = true;
                        });
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isDeepCompression
                          ? const Color(0xFF7046A8).withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isDeepCompression
                            ? const Color(0xFF7046A8)
                            : Colors.grey.withValues(alpha: 0.3),
                        width: _isDeepCompression ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isDeepCompression
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: _isDeepCompression
                              ? const Color(0xFF7046A8)
                              : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Deep Stream Compression',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDeepUnlocked
                                          ? const Color(0xFFE8F5E9)
                                          : const Color(0xFFF3E8FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isDeepUnlocked
                                          ? '✨ Unlocked'
                                          : 'Watch Ad',
                                      style: TextStyle(
                                        color: isDeepUnlocked
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFF7046A8),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Deep object purge & multi-pass stream deflate for maximum size reduction.',
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
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Optimization Overview Card
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
                  'Optimization Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Re-encodes document streams with standard Flate/Deflate compression.\n'
                  '• Trims orphaned font tables, redundant metadata, and historical revisions.\n'
                  '• Preserves text sharpness and vector rendering without lossy artifacts.',
                  style: TextStyle(fontSize: 12.5, color: secondaryText, height: 1.4),
                ),
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
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
            onPressed: _isCompressing ? null : _compressPdf,
            icon: _isCompressing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.compress_rounded),
            label: Text(
              _isCompressing ? 'Optimizing PDF...' : 'Compress PDF',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
