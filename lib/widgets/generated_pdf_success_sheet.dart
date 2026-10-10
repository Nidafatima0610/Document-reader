import 'dart:io';

import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/document_save_service.dart';
import 'package:all_documents_reader/views/pdf_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Unified bottom sheet displayed after any PDF conversion/generation workflow
/// (Camera Scan, Images to PDF, Text to PDF, Merge, Split, Rotate, etc.).
/// Provides the 4 key actions:
/// 1. Open PDF
/// 2. Save to Device (via Android SAF)
/// 3. Share
/// 4. Done
class GeneratedPdfSuccessSheet extends StatefulWidget {
  final File file;
  final String title;
  final DocumentsModel document;
  final int pageCount;
  final String formattedSize;
  final String? subtitle;
  final VoidCallback? onDone;

  const GeneratedPdfSuccessSheet({
    super.key,
    required this.file,
    required this.title,
    required this.document,
    this.pageCount = 1,
    this.formattedSize = '',
    this.subtitle,
    this.onDone,
  });

  static Future<void> show({
    required BuildContext context,
    required File file,
    String? title,
    required DocumentsModel document,
    int? pageCount,
    String? formattedSize,
    String? subtitle,
    VoidCallback? onDone,
  }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GeneratedPdfSuccessSheet(
        file: file,
        title: title ?? document.name,
        document: document,
        pageCount: pageCount ?? 1,
        formattedSize: formattedSize ?? '',
        subtitle: subtitle,
        onDone: onDone,
      ),
    );
  }

  @override
  State<GeneratedPdfSuccessSheet> createState() => _GeneratedPdfSuccessSheetState();
}

class _GeneratedPdfSuccessSheetState extends State<GeneratedPdfSuccessSheet> {
  bool _isSaving = false;
  String? _savedLocation;

  Future<void> _handleSaveToDevice() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final result = await DocumentSaveService.instance.savePdfToDevice(
      context: context,
      sourceFile: widget.file,
      defaultFileName: widget.document.name,
      document: widget.document,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (result.success && result.savedPath != null) {
          _savedLocation = result.savedPath;
        }
      });
    }
  }

  Future<void> _handleShare() async {
    try {
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(widget.file.path)],
        subject: widget.title,
        text: 'Document: ${widget.document.name}',
      );
    } catch (e) {
      debugPrint('[GeneratedPdfSuccessSheet] Share error: $e');
    }
  }

  void _handleOpenPdf() {
    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          file: widget.file,
          title: widget.title,
          document: widget.document,
        ),
      ),
    );
  }

  void _handleDone() {
    Navigator.pop(context); // Close bottom sheet
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Navigator.pop(context); // Return to previous screen/Tools
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1A24) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Success badge
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF2E7D32),
              size: 44,
            ),
          ),
          const SizedBox(height: 14),

          // Title
          const Text(
            'PDF Created Successfully!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),

          // Document info chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2B2435) : const Color(0xFFF3EDFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF3B314A) : const Color(0xFFE4D7F5),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFFD32F2F),
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.document.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle ??
                            '${widget.pageCount} ${widget.pageCount == 1 ? "page" : "pages"} • ${widget.formattedSize}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_savedLocation != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_rounded, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Saved to device successfully!',
                      style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Primary Action: Open PDF
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7046A8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: _handleOpenPdf,
              icon: const Icon(Icons.chrome_reader_mode_rounded, size: 20),
              label: const Text(
                'Open PDF',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Secondary Row: Save to Device & Share
          Row(
            children: [
              // Save to Device
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7046A8),
                      side: const BorderSide(color: Color(0xFF7046A8), width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isSaving ? null : _handleSaveToDevice,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded, size: 19),
                    label: Text(
                      _savedLocation != null ? 'Saved to Device' : 'Save to Device',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Share
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7046A8),
                      side: const BorderSide(color: Color(0xFF7046A8), width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _handleShare,
                    icon: const Icon(Icons.share_rounded, size: 19),
                    label: const Text(
                      'Share',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Done action
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _handleDone,
              child: const Text('Done', style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
