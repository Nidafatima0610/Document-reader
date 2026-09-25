import 'dart:io';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/ad_mob_service.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:all_documents_reader/services/pdf_to_image_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Screen allowing users to select a PDF and convert pages into high-resolution PNG image files
class PdfToImageView extends StatefulWidget {
  final String? initialPdfPath;
  final InspectedPdfInfo? initialPdfInfo;

  const PdfToImageView({
    super.key,
    this.initialPdfPath,
    this.initialPdfInfo,
  });

  @override
  State<PdfToImageView> createState() => _PdfToImageViewState();
}

class _PdfToImageViewState extends State<PdfToImageView> {
  InspectedPdfInfo? _pdfInfo;
  bool _isAllPages = true;
  bool _isUltraHd = false;
  final Set<int> _selectedPages = {};
  final TextEditingController _rangeController = TextEditingController();

  bool _isConverting = false;
  double _progress = 0.0;
  String _statusMessage = '';

  bool get isUltraHdUnlocked =>
      AdMobService.instance.isPerkUnlocked('ultra_hd_pdf_export');

  void _selectStandard() {
    if (mounted) {
      setState(() {
        _isUltraHd = false;
      });
    }
  }

  Future<bool> _selectUltraHd({bool autoConvertOnSuccess = false}) async {
    if (isUltraHdUnlocked) {
      if (mounted) {
        setState(() {
          _isUltraHd = true;
        });
      }
      if (autoConvertOnSuccess && _pdfInfo != null && !_isConverting) {
        _convertPdf();
      }
      return true;
    }

    // Show explicit prompt to watch ad
    final unlocked = await AdMobService.instance.showRewardedAdPrompt(
      context,
      title: 'Unlock Ultra HD (300 DPI)',
      description: 'Watch a short ad to unlock Ultra HD export.',
      perkKey: 'ultra_hd_pdf_export',
      actionButtonLabel: 'Watch Ad',
      cancelButtonLabel: 'Cancel',
    );

    if (mounted) {
      if (unlocked) {
        setState(() {
          _isUltraHd = true;
        });
        if (autoConvertOnSuccess && _pdfInfo != null && !_isConverting) {
          _convertPdf();
        }
        return true;
      } else {
        setState(() {
          _isUltraHd = false;
        });
        return false;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialPdfInfo != null) {
      _applyPdfInfo(widget.initialPdfInfo!);
    } else if (widget.initialPdfPath != null) {
      _loadInitialPdf(widget.initialPdfPath!);
    }
  }

  void _applyPdfInfo(InspectedPdfInfo info) {
    _pdfInfo = info;
    _isAllPages = true;
    _selectedPages.clear();
    for (int i = 1; i <= info.pageCount; i++) {
      _selectedPages.add(i);
    }
    _rangeController.text = '1-${info.pageCount}';
  }

  Future<void> _loadInitialPdf(String path) async {
    try {
      final info = await PdfToImageService.instance.inspectPdf(path);
      if (mounted) {
        setState(() {
          _applyPdfInfo(info);
        });
      }
    } catch (e) {
      debugPrint('Error inspecting initial PDF: $e');
    }
  }

  @override
  void dispose() {
    _rangeController.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result.isEmpty || result.first.path == null) {
        return; // User cancelled picker
      }

      final filePath = result.first.path!;
      final info = await PdfToImageService.instance.inspectPdf(filePath);

      setState(() {
        _applyPdfInfo(info);
      });
    } catch (e) {
      debugPrint('Error selecting PDF: $e');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Invalid PDF'),
            ],
          ),
          content: Text(
            'The selected file could not be opened as a valid PDF: $e',
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

  void _togglePageSelection(int page) {
    setState(() {
      if (_selectedPages.contains(page)) {
        if (_selectedPages.length > 1) {
          _selectedPages.remove(page);
        }
      } else {
        _selectedPages.add(page);
      }
      _syncRangeTextFromSet();
    });
  }

  void _syncRangeTextFromSet() {
    if (_selectedPages.isEmpty) {
      _rangeController.text = '';
      return;
    }
    final sorted = _selectedPages.toList()..sort();
    _rangeController.text = sorted.join(', ');
  }

  Future<void> _convertPdf() async {
    if (_pdfInfo == null || _isConverting) return;

    final List<int> pagesToConvert = _isAllPages
        ? List.generate(_pdfInfo!.pageCount, (i) => i + 1)
        : (_selectedPages.toList()..sort());

    if (pagesToConvert.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: const Text('Please select at least one page to convert.'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (_isUltraHd && !isUltraHdUnlocked) {
      final unlocked = await _selectUltraHd();
      if (!unlocked) {
        return;
      }
    }

    setState(() {
      _isConverting = true;
      _progress = 0.0;
      _statusMessage = 'Starting conversion...';
    });

    try {
      final result = await PdfToImageService.instance.convertPdfToImages(
        pdfPath: _pdfInfo!.path,
        pageNumbers: pagesToConvert,
        scale: _isUltraHd ? 3.0 : 1.5,
        onProgress: (current, total, status) {
          if (mounted) {
            setState(() {
              _progress = current / total;
              _statusMessage = status;
            });
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _isConverting = false;
      });

      _showSuccessDialog(result);
    } catch (e) {
      debugPrint('Error converting PDF to images: $e');
      if (!mounted) return;
      setState(() {
        _isConverting = false;
      });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Conversion Failed'),
            ],
          ),
          content: Text(
            'An error occurred during conversion: $e\n\nPlease check storage permissions and try again.',
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

  void _showSuccessDialog(PdfToImageResult result) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
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
                'Images Generated!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF2D2435),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${result.pageCount} ${result.pageCount == 1 ? "page" : "pages"} converted to PNG images and added to Documents.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),

              // Image preview list
              if (result.generatedFiles.isNotEmpty)
                Container(
                  height: 110,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: result.generatedFiles.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final imgFile = result.generatedFiles[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 80,
                          color: isDark ? Colors.white10 : Colors.black12,
                          child: Image.file(
                            imgFile,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(Icons.image),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await AdMobService.instance.showInterstitialAd(
                context: context,
                triggerReason: 'pdf_to_image_done',
              );
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Done'),
          ),
          if (result.generatedFiles.isNotEmpty)
            ElevatedButton.icon(
              icon: const Icon(Icons.image_outlined, size: 18),
              label: const Text('Open First Image'),
              onPressed: () {
                Navigator.pop(dialogContext);
                final firstFile = result.generatedFiles.first;
                final doc = DocumentsModel(
                  name: firstFile.path.split(RegExp(r'[/\\]')).last,
                  path: firstFile.path,
                  type: 'image',
                  createdAt: DateTime.now(),
                );
                DocumentsStorageService.instance.recordDocumentOpened(doc);
                _openImageViewer(firstFile.path, doc.name);
              },
            ),
        ],
      ),
    );
  }

  void _openImageViewer(String path, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(name),
          ),
          body: Container(
            color: Colors.black,
            child: Center(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
            ),
          ),
        ),
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
        title: const Text('PDF to Image'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_pdfInfo != null && !_isConverting)
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Change PDF',
              onPressed: _pickPdf,
            ),
        ],
      ),
      body: _pdfInfo == null
          ? _buildEmptyState(isDark, cardBg, primaryText, secondaryText)
          : _buildConfigView(isDark, primaryText, secondaryText, cardBg),
      bottomNavigationBar: _pdfInfo != null
          ? _buildBottomBar(isDark, cardBg)
          : null,
    );
  }

  Widget _buildEmptyState(
    bool isDark,
    Color cardBg,
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
                color: const Color(0xFF00897B).withValues(alpha: isDark ? 0.25 : 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_size_select_actual_outlined,
                size: 52,
                color: Color(0xFF00897B),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select PDF to Extract Images',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose an existing PDF document to convert pages into high-resolution lossless PNG image files.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: secondaryText, height: 1.4),
            ),
            const SizedBox(height: 20),

            Wrap(
              spacing: 8,
              children: ['Lossless PNG', 'Custom Page Range', '300 DPI Clarity'].map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2536) : const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00796B),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Prominent Quality Options Section
            _buildQualityOptionsSection(isDark, cardBg, primaryText, secondaryText),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
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
        // Selected PDF Info Card
        Card(
          color: cardBg,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD32F2F).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFFD32F2F),
                  ),
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
                      const SizedBox(height: 4),
                      Text(
                        '${_pdfInfo!.pageCount} pages • ${_pdfInfo!.formattedSize}',
                        style: TextStyle(fontSize: 12, color: secondaryText),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _isConverting ? null : _pickPdf,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('Change', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Page Selection Header
        Text(
          'Page Selection',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 8),

        // All vs Custom Range Segmented Control
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: true,
              label: Text('All Pages (${_pdfInfo!.pageCount})'),
              icon: const Icon(Icons.select_all_rounded, size: 18),
            ),
            const ButtonSegment(
              value: false,
              label: Text('Custom Range'),
              icon: Icon(Icons.filter_list_rounded, size: 18),
            ),
          ],
          selected: {_isAllPages},
          onSelectionChanged: _isConverting
              ? null
              : (val) {
                  setState(() {
                    _isAllPages = val.first;
                    if (_isAllPages) {
                      _selectedPages.clear();
                      for (int i = 1; i <= _pdfInfo!.pageCount; i++) {
                        _selectedPages.add(i);
                      }
                      _rangeController.text = '1-${_pdfInfo!.pageCount}';
                    }
                  });
                },
        ),
        const SizedBox(height: 12),

        // Custom Range controls
        if (!_isAllPages) ...[
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
                    controller: _rangeController,
                    enabled: !_isConverting,
                    onChanged: _onRangeTextChanged,
                    decoration: InputDecoration(
                      labelText: 'Page Range (e.g. 1-3, 5, 8)',
                      hintText: 'Enter pages to convert',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.format_list_numbered_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tap pages to select/deselect:',
                        style: TextStyle(fontSize: 12.5, color: secondaryText),
                      ),
                      Text(
                        '${_selectedPages.length} selected',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00897B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Quick-tap page chip grid
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(_pdfInfo!.pageCount, (index) {
                      final pNum = index + 1;
                      final isSelected = _selectedPages.contains(pNum);
                      return FilterChip(
                        label: Text('P$pNum'),
                        selected: isSelected,
                        selectedColor: const Color(0xFF00897B).withValues(alpha: 0.2),
                        checkmarkColor: const Color(0xFF00897B),
                        onSelected: _isConverting
                            ? null
                            : (_) => _togglePageSelection(pNum),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _buildQualityOptionsSection(isDark, cardBg, primaryText, secondaryText),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBottomBar(bool isDark, Color cardBg) {
    final count = _isAllPages ? _pdfInfo!.pageCount : _selectedPages.length;

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
            if (_isConverting) ...[
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: isDark ? const Color(0xFF382F45) : const Color(0xFFEDE7F6),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00897B)),
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
            ],
            // Quality Selector
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1729) : const Color(0xFFF3F0F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _isConverting ? null : _selectStandard,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !_isUltraHd
                              ? (isDark ? const Color(0xFF382F45) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: !_isUltraHd
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            "Standard (150 DPI) • Free",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: !_isUltraHd ? FontWeight.bold : FontWeight.normal,
                              color: !_isUltraHd
                                  ? (isDark ? Colors.white : const Color(0xFF2D2435))
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _isConverting ? null : () => _selectUltraHd(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _isUltraHd
                              ? (isDark ? const Color(0xFF382F45) : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _isUltraHd
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isUltraHdUnlocked
                                    ? Icons.check_circle_rounded
                                    : Icons.stars_rounded,
                                size: 14,
                                color: _isUltraHd
                                    ? const Color(0xFF00897B)
                                    : (isUltraHdUnlocked ? const Color(0xFF2E7D32) : Colors.grey),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isUltraHdUnlocked
                                    ? "Ultra HD (300 DPI) • Unlocked"
                                    : "Ultra HD (300 DPI)",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _isUltraHd ? FontWeight.bold : FontWeight.normal,
                                  color: _isUltraHd
                                      ? const Color(0xFF00897B)
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                ),
                onPressed: _isConverting || count == 0 ? null : _convertPdf,
                icon: _isConverting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.image_outlined),
                label: Text(
                  _isConverting
                      ? 'Converting Pages...'
                      : _isUltraHd
                          ? 'Convert to Images (Ultra HD 300 DPI)'
                          : 'Convert to Images (Standard 150 DPI)',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityOptionsSection(
    bool isDark,
    Color cardBg,
    Color primaryText,
    Color secondaryText,
  ) {
    final bool unlocked = isUltraHdUnlocked;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE8E0F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7046A8).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: Color(0xFF7046A8),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Export Quality',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Option 1: Standard — 150 DPI — Free
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isConverting ? null : _selectStandard,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: !_isUltraHd
                    ? (isDark ? const Color(0xFF2C2238) : const Color(0xFFF7F4FD))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !_isUltraHd
                      ? const Color(0xFF7046A8)
                      : (isDark ? Colors.white12 : Colors.black12),
                  width: !_isUltraHd ? 1.8 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    !_isUltraHd
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: !_isUltraHd ? const Color(0xFF7046A8) : secondaryText,
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
                                'Standard — 150 DPI',
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
                          'Standard resolution • 100% Free • No ads required',
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

          // Option 2: Ultra HD — 300 DPI — Watch Ad to Unlock
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isConverting ? null : () => _selectUltraHd(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isUltraHd
                    ? (isDark ? const Color(0xFF2C2238) : const Color(0xFFF7F4FD))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isUltraHd
                      ? const Color(0xFF7046A8)
                      : (isDark ? Colors.white12 : Colors.black12),
                  width: _isUltraHd ? 1.8 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isUltraHd
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: _isUltraHd ? const Color(0xFF7046A8) : secondaryText,
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
                                'Ultra HD — 300 DPI',
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
                              ? 'Studio quality 300 DPI • Session unlocked'
                              : 'Studio quality 300 DPI • Watch 1 ad to unlock',
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
}
