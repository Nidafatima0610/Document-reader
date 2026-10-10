import 'dart:io';

import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/ad_mob_service.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/pdf_generator_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:all_documents_reader/widgets/generated_pdf_success_sheet.dart';

/// Screen allowing users to select, preview, reorder images and convert them into a real PDF
class ImagesToPdfView extends StatefulWidget {
  const ImagesToPdfView({super.key});

  @override
  State<ImagesToPdfView> createState() => _ImagesToPdfViewState();
}

class _ImagesToPdfViewState extends State<ImagesToPdfView> {
  final List<PlatformFile> _selectedImages = [];
  final Set<String> _selectedPaths = {};
  final TextEditingController _fileNameController = TextEditingController();

  bool _isGenerating = false;
  String _statusMessage = '';
  double _progress = 0.0;
  bool _isStudioQuality = false;

  bool get isStudioUnlocked =>
      AdMobService.instance.isPerkUnlocked('studio_hd_images_to_pdf');

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  int _getImageFileSize(String? path) {
    if (path == null) return 0;
    try {
      final file = File(path);
      if (file.existsSync()) {
        return file.lengthSync();
      }
    } catch (_) {}
    return 0;
  }

  Future<void> _pickImages() async {
    try {
      final List<PlatformFile> pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
      );

      if (pickedFiles.isEmpty) {
        // User cancelled picker or selected nothing
        return;
      }

      int duplicateCount = 0;
      final List<PlatformFile> newFiles = [];

      for (final file in pickedFiles) {
        if (file.path == null) continue;
        final path = file.path!;

        if (_selectedPaths.contains(path)) {
          duplicateCount++;
          continue;
        }

        if (File(path).existsSync()) {
          _selectedPaths.add(path);
          newFiles.add(file);
        }
      }

      if (newFiles.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(newFiles);
        });
      }

      if (duplicateCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            content: Text(
              '$duplicateCount duplicate ${duplicateCount == 1 ? "image was" : "images were"} skipped',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Could not access selected images: $e'),
          ),
        );
      }
    }
  }

  void _removeImageAt(int index) {
    setState(() {
      final removed = _selectedImages.removeAt(index);
      if (removed.path != null) {
        _selectedPaths.remove(removed.path!);
      }
    });
  }

  void _confirmClearAll() {
    if (_selectedImages.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text('Clear All Images?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove all selected images from this session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _selectedImages.clear();
                _selectedPaths.clear();
              });
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf() async {
    if (_selectedImages.isEmpty || _isGenerating) return;

    if (_isStudioQuality && !isStudioUnlocked) {
      final unlocked = await AdMobService.instance.showRewardedAdPrompt(
        context,
        title: 'Unlock Studio HD PDF',
        description: 'Watch a short ad to unlock this advanced option',
        perkKey: 'studio_hd_images_to_pdf',
        actionButtonLabel: 'Watch Ad',
      );
      if (!unlocked) {
        setState(() {
          _isStudioQuality = false;
        });
        return;
      }
    }

    setState(() {
      _isGenerating = true;
      _statusMessage = 'Preparing images...';
      _progress = 0.0;
    });

    try {
      final imagePaths = _selectedImages
          .map((f) => f.path)
          .whereType<String>()
          .toList();

      final result = await PdfGeneratorService.instance.generatePdfFromImages(
        imagePaths: imagePaths,
        customFileName: _fileNameController.text.trim(),
        studioQuality: _isStudioQuality,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _progress = current / total;
              _statusMessage = 'Converting image $current of $total...';
            });
          }
        },
      );

      // Create DocumentsModel and save to persistent storage
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
        _selectedImages.clear();
        _selectedPaths.clear();
        _fileNameController.clear();
      });

      _showSuccessDialog(newDoc, result);
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (!mounted) return;

      setState(() {
        _isGenerating = false;
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Conversion Failed'),
            ],
          ),
          content: Text(
            'An error occurred while creating the PDF: $e\n\nPlease verify your images are readable and try again.',
          ),
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

  void _showSuccessDialog(DocumentsModel document, PdfGenerationResult result) {
    GeneratedPdfSuccessSheet.show(
      context: context,
      document: document,
      file: result.file,
      subtitle: '${result.pageCount} ${result.pageCount == 1 ? "page" : "pages"} • ${result.formattedSize}',
      onDone: () async {
        await AdMobService.instance.showInterstitialAd(
          context: context,
          triggerReason: 'images_to_pdf_done',
        );
        if (mounted) {
          Navigator.pop(context); // Return to Tools
        }
      },
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
        title: const Text('Images to PDF'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedImages.isNotEmpty && !_isGenerating)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear All',
              onPressed: _confirmClearAll,
            ),
        ],
      ),
      body: _selectedImages.isEmpty
          ? _buildEmptyState(isDark, primaryText, secondaryText)
          : _buildImagesList(isDark, primaryText, secondaryText, cardBg),
      bottomNavigationBar: _selectedImages.isNotEmpty
          ? _buildBottomBar(isDark, cardBg)
          : null,
    );
  }

  Widget _buildEmptyState(
    bool isDark,
    Color primaryText,
    Color secondaryText,
  ) {
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
                color: const Color(0xFF6C4AB6).withValues(alpha: isDark ? 0.25 : 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                size: 52,
                color: Color(0xFF7046A8),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select Images to Convert',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick multiple photos from your device to merge into a single PDF document. You can reorder pages before saving.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Format tags
            Wrap(
              spacing: 8,
              children: ['JPG', 'JPEG', 'PNG', 'WEBP', 'BMP'].map((fmt) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2536)
                        : const Color(0xFFEFE8F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    fmt,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7046A8),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            _buildQualitySelector(isDark),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_photo_alternate_rounded),
                label: const Text(
                  'Select Images',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesList(
    bool isDark,
    Color primaryText,
    Color secondaryText,
    Color cardBg,
  ) {
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
                    '${_selectedImages.length} ${_selectedImages.length == 1 ? "Image" : "Images"} Selected',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                  Text(
                    'Drag handle to reorder PDF pages',
                    style: TextStyle(fontSize: 12, color: secondaryText),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _isGenerating ? null : _pickImages,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                label: const Text('Add More', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ),

        // Custom File Name Input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            child: TextField(
              controller: _fileNameController,
              enabled: !_isGenerating,
              decoration: InputDecoration(
                hintText: 'PDF File Name (e.g. MyDocument)',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
                prefixIcon: const Icon(
                  Icons.edit_note_rounded,
                  color: Color(0xFF7046A8),
                  size: 22,
                ),
                suffixText: '.pdf',
                suffixStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7046A8),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),

        // Reorderable Image List
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _selectedImages.length,
            // ignore: deprecated_member_use
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final item = _selectedImages.removeAt(oldIndex);
                _selectedImages.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final image = _selectedImages[index];
              final path = image.path;

              return Card(
                key: ValueKey(path ?? 'img_$index'),
                color: cardBg,
                elevation: isDark ? 2 : 1,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      // Drag handle
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
                      const SizedBox(width: 6),

                      // Image Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 50,
                          height: 50,
                          color: isDark
                              ? const Color(0xFF2C2536)
                              : const Color(0xFFEFE8F6),
                          child: path != null && File(path).existsSync()
                              ? Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                    Icons.broken_image_rounded,
                                    color: Colors.grey,
                                  ),
                                )
                              : const Icon(
                                  Icons.image_not_supported_rounded,
                                  color: Colors.grey,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // File info + page indicator
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF382F45)
                                        : const Color(0xFFEDE7F6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Page ${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7046A8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatBytes(_getImageFileSize(image.path)),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: secondaryText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              image.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Remove button
                      if (!_isGenerating)
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: Colors.redAccent,
                          ),
                          tooltip: 'Remove',
                          onPressed: () => _removeImageAt(index),
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
            if (!_isGenerating) ...[
              _buildQualitySelector(isDark),
              const SizedBox(height: 6),
            ],
            if (_isGenerating) ...[
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: isDark
                    ? const Color(0xFF382F45)
                    : const Color(0xFFEDE7F6),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF7046A8)),
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
            ],
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
                    : const Icon(Icons.picture_as_pdf_rounded, size: 20),
                label: Text(
                  _isGenerating
                      ? 'Converting Images...'
                      : 'Convert to PDF (${_selectedImages.length} ${_selectedImages.length == 1 ? "page" : "pages"})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualitySelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            Icons.high_quality_rounded,
            color: Color(0xFF7046A8),
            size: 18,
          ),
          const SizedBox(width: 8),
          const Text(
            'Quality:',
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
                _isStudioQuality = false;
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: !_isStudioQuality
                    ? const Color(0xFF7046A8).withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Standard',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: !_isStudioQuality
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: !_isStudioQuality
                      ? const Color(0xFF7046A8)
                      : (isDark ? Colors.grey[400] : Colors.grey[700]),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Studio HD
          InkWell(
            onTap: () async {
              if (isStudioUnlocked) {
                setState(() {
                  _isStudioQuality = true;
                });
              } else {
                final unlocked =
                    await AdMobService.instance.showRewardedAdPrompt(
                  context,
                  title: 'Unlock Studio HD PDF',
                  description:
                      'Studio HD maximizes PDF rendering density and uncompressed image fidelity for crystal-clear prints.',
                  perkKey: 'studio_hd_images_to_pdf',
                  actionButtonLabel: 'Watch Ad',
                  unlockNotice:
                      'Watch a short Google test ad to unlock Studio HD quality for this session. Standard quality is always 100% free.',
                  perkUnlockedMessage: 'Studio HD PDF Unlocked!',
                );
                if (unlocked && mounted) {
                  setState(() {
                    _isStudioQuality = true;
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
                color: _isStudioQuality
                    ? const Color(0xFF7046A8)
                    : (isDark
                        ? const Color(0xFF2C223A)
                        : const Color(0xFFEDE5F8)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Text(
                    'Studio HD',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: _isStudioQuality
                          ? Colors.white
                          : const Color(0xFF7046A8),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isStudioUnlocked ? '✨' : '🎬',
                    style: const TextStyle(fontSize: 10),
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
