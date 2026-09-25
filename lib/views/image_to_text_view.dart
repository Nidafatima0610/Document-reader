import 'dart:io';
import 'package:all_documents_reader/core/config/app_config.dart';
import 'package:all_documents_reader/services/ocr_service.dart';
import 'package:all_documents_reader/views/ai_document_assistant_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Screen allowing users to select an image, run on-device OCR, and edit/copy/save recognized text
class ImageToTextView extends StatefulWidget {
  const ImageToTextView({super.key});

  @override
  State<ImageToTextView> createState() => _ImageToTextViewState();
}

class _ImageToTextViewState extends State<ImageToTextView> {
  String? _selectedImagePath;
  String? _selectedImageName;
  int _imageSizeBytes = 0;

  final TextEditingController _recognizedTextController = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController();

  bool _isRecognizing = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _recognizedTextController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
      );

      if (result.isEmpty || result.first.path == null) {
        return;
      }

      final file = File(result.first.path!);
      if (!file.existsSync()) return;

      setState(() {
        _selectedImagePath = file.path;
        _selectedImageName = file.path.split(RegExp(r'[/\\]')).last;
        _imageSizeBytes = file.lengthSync();
        _recognizedTextController.clear();
      });

      _performOcr();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Could not access selected image: $e'),
        ),
      );
    }
  }

  Future<void> _performOcr() async {
    if (_selectedImagePath == null) return;

    setState(() {
      _isRecognizing = true;
    });

    try {
      final result = await OcrService.instance.recognizeTextFromImage(
        _selectedImagePath!,
      );

      if (!mounted) return;
      setState(() {
        _isRecognizing = false;
        _recognizedTextController.text = result.text;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecognizing = false;
      });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFFC2185B)),
              SizedBox(width: 8),
              Text('OCR Processing'),
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

  void _copyToClipboard() {
    final text = _recognizedTextController.text;
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
            Text('Recognized text copied to clipboard!'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveAsDocument() async {
    final text = _recognizedTextController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final doc = await OcrService.instance.saveExtractedTextAsDocument(
        text: text,
        customFileName: _fileNameController.text.trim().isNotEmpty
            ? _fileNameController.text.trim()
            : '${_selectedImageName ?? "OCR"}_text',
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
              onPressed: () => Navigator.pop(context),
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
        title: const Text('Image to Text (OCR)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedImagePath != null && !_isRecognizing)
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              tooltip: 'Change Image',
              onPressed: _pickImage,
            ),
        ],
      ),
      body: _selectedImagePath == null
          ? _buildEmptyState(isDark, primaryText, secondaryText)
          : _buildOcrView(isDark, primaryText, secondaryText, cardBg),
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
                color: const Color(0xFFC2185B).withValues(alpha: isDark ? 0.25 : 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.document_scanner_outlined,
                size: 52,
                color: Color(0xFFC2185B),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Recognize Text from Image',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a document scan, receipt, or photo to extract editable text on-device using machine learning.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: secondaryText, height: 1.4),
            ),
            const SizedBox(height: 20),

            Wrap(
              spacing: 8,
              children: ['On-Device ML', 'High Accuracy', 'Offline'].map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2536) : const Color(0xFFFCE4EC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC2185B),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC2185B),
                  foregroundColor: Colors.white,
                ),
                onPressed: _pickImage,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text(
                  'Select Image',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOcrView(
    bool isDark,
    Color primaryText,
    Color secondaryText,
    Color cardBg,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Image Thumbnail Card
        Card(
          color: cardBg,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Image.file(
                      File(_selectedImagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedImageName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatBytes(_imageSizeBytes),
                        style: TextStyle(fontSize: 12, color: secondaryText),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _isRecognizing ? null : _performOcr,
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Re-run', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Recognized Text Card
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
                      'Recognized Text',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: primaryText,
                      ),
                    ),
                    if (!_isRecognizing && _recognizedTextController.text.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.select_all_rounded, size: 20),
                            tooltip: 'Select All',
                            onPressed: () {
                              _recognizedTextController.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: _recognizedTextController.text.length,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 20),
                            tooltip: 'Copy to Clipboard',
                            onPressed: _copyToClipboard,
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            tooltip: 'Clear',
                            onPressed: () {
                              setState(() {
                                _recognizedTextController.clear();
                              });
                            },
                          ),
                        ],
                      ),
                  ],
                ),
                const Divider(),
                if (_isRecognizing)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                            color: Color(0xFFC2185B),
                          ),
                          SizedBox(height: 16),
                          Text('Scanning image and recognizing text...'),
                        ],
                      ),
                    ),
                  )
                else
                  TextField(
                    controller: _recognizedTextController,
                    maxLines: 12,
                    minLines: 8,
                    decoration: const InputDecoration(
                      hintText: 'No text recognized yet.',
                      border: InputBorder.none,
                    ),
                    style: TextStyle(fontSize: 13.5, color: primaryText),
                  ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_recognizedTextController.text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length} words',
                      style: TextStyle(fontSize: 12, color: secondaryText),
                    ),
                    if (!_isRecognizing && _recognizedTextController.text.isNotEmpty)
                      Row(
                        children: [
                          if (AppConfig.isAiFeatureEnabled) ...[
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AiDocumentAssistantView(
                                      initialText: _recognizedTextController.text,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF7046A8)),
                              label: const Text('Analyze with AI', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                          ],
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC2185B),
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}
