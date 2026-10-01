import 'dart:io';
import 'package:all_documents_reader/models/scanned_page_model.dart';
import 'package:all_documents_reader/services/scanner_image_processing_service.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Interactive page editing screen for cropping, perspective boundary selection,
/// enhancement filters (Original, Enhanced, B&W, Grayscale), and 90° rotation.
class ScanToPdfEditorView extends StatefulWidget {
  final String imagePath;
  final int pageNumber;

  const ScanToPdfEditorView({
    super.key,
    required this.imagePath,
    this.pageNumber = 1,
  });

  @override
  State<ScanToPdfEditorView> createState() => _ScanToPdfEditorViewState();
}

enum _ActiveCropHandle {
  none,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  topEdge,
  bottomEdge,
  leftEdge,
  rightEdge,
  center,
}

class _ScanToPdfEditorViewState extends State<ScanToPdfEditorView> {
  late String _currentOriginalPath;
  late String _currentProcessedPath;
  DocumentFilterType _currentFilter = DocumentFilterType.enhanced;
  int _rotationDegrees = 0;

  // Normalized crop bounds (0.0 to 1.0)
  Rect _cropRect = const Rect.fromLTWH(0.04, 0.04, 0.92, 0.92);
  _ActiveCropHandle _activeHandle = _ActiveCropHandle.none;
  Offset? _lastPanPosition;

  bool _isProcessing = false;
  String _processingMessage = '';
  double _imageWidth = 1000;
  double _imageHeight = 1400;

  @override
  void initState() {
    super.initState();
    _currentOriginalPath = widget.imagePath;
    _currentProcessedPath = widget.imagePath;
    _loadImageDimensions();
    // Default to 'enhanced' for crisp document reading
    _applyInitialFilter();
  }

  void _loadImageDimensions() {
    final file = File(_currentOriginalPath);
    if (!file.existsSync()) return;

    try {
      final bytes = file.readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        setState(() {
          _imageWidth = decoded.width.toDouble();
          _imageHeight = decoded.height.toDouble();
        });
      }
    } catch (e) {
      debugPrint('[ScanToPdfEditorView] Error decoding dimensions: $e');
    }
  }

  Future<void> _applyInitialFilter() async {
    await _applyFilter(_currentFilter);
  }

  Future<void> _applyFilter(DocumentFilterType filter) async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Applying ${filter.label} filter...';
    });

    try {
      final now = DateTime.now().microsecondsSinceEpoch;
      final parentDir = File(_currentOriginalPath).parent.path;
      final outPath = '$parentDir/proc_${filter.name}_$now.jpg';

      final file = await ScannerImageProcessingService.instance.applyFilter(
        inputPath: _currentOriginalPath,
        filter: filter,
        outputPath: outPath,
      );

      if (mounted) {
        setState(() {
          _currentProcessedPath = file.path;
          _currentFilter = filter;
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('[ScanToPdfEditorView] Filter error: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _rotatePage() async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Rotating 90°...';
    });

    try {
      final now = DateTime.now().microsecondsSinceEpoch;
      final parentDir = File(_currentOriginalPath).parent.path;

      final outOriginal = '$parentDir/orig_rot_$now.jpg';
      final newOrig = await ScannerImageProcessingService.instance.rotateImage(
        inputPath: _currentOriginalPath,
        degrees: 90,
        outputPath: outOriginal,
      );

      final outProc = '$parentDir/proc_rot_$now.jpg';
      final newProc = await ScannerImageProcessingService.instance.rotateImage(
        inputPath: _currentProcessedPath,
        degrees: 90,
        outputPath: outProc,
      );

      if (mounted) {
        setState(() {
          _currentOriginalPath = newOrig.path;
          _currentProcessedPath = newProc.path;
          _rotationDegrees = (_rotationDegrees + 90) % 360;
          // Swap width/height
          final tmp = _imageWidth;
          _imageWidth = _imageHeight;
          _imageHeight = tmp;
          // Reset crop rectangle to proportional bounds
          _cropRect = const Rect.fromLTWH(0.04, 0.04, 0.92, 0.92);
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('[ScanToPdfEditorView] Rotation error: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _presetA4() {
    final isLandscape = _imageWidth > _imageHeight;
    final double targetAspect = isLandscape ? 1.414 : (1 / 1.414);

    setState(() {
      double w = 0.88;
      double h = w / targetAspect * (_imageWidth / _imageHeight);
      if (h > 0.92) {
        h = 0.92;
        w = h * targetAspect * (_imageHeight / _imageWidth);
      }
      w = w.clamp(0.1, 0.96);
      h = h.clamp(0.1, 0.96);

      _cropRect = Rect.fromLTWH((1.0 - w) / 2, (1.0 - h) / 2, w, h);
    });
  }

  void _presetFull() {
    setState(() {
      _cropRect = const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0);
    });
  }

  void _presetCard() {
    // Standard credit card / ID card aspect ratio is 1.586
    const double targetAspect = 1.586;
    setState(() {
      double w = 0.84;
      double h = w / targetAspect * (_imageWidth / _imageHeight);
      if (h > 0.9) {
        h = 0.9;
        w = h * targetAspect * (_imageHeight / _imageWidth);
      }
      _cropRect = Rect.fromLTWH((1.0 - w) / 2, (1.0 - h) / 2, w, h);
    });
  }

  Future<void> _commitPageAndReturn() async {
    setState(() {
      _isProcessing = true;
      _processingMessage = 'Finalizing scanned page...';
    });

    try {
      String finalImagePath = _currentProcessedPath;

      // If cropped beyond boundary margin, execute physical crop
      final isFullCrop = _cropRect.left <= 0.01 &&
          _cropRect.top <= 0.01 &&
          _cropRect.right >= 0.99 &&
          _cropRect.bottom >= 0.99;

      if (!isFullCrop) {
        final now = DateTime.now().microsecondsSinceEpoch;
        final parentDir = File(_currentOriginalPath).parent.path;
        final cropOutPath = '$parentDir/final_crop_$now.jpg';

        final croppedFile = await ScannerImageProcessingService.instance.cropImage(
          inputPath: _currentOriginalPath,
          normalizedRect: _cropRect,
          outputPath: cropOutPath,
        );

        // Apply filter to cropped image
        final filterOutPath = '$parentDir/final_filt_$now.jpg';
        final filteredFile = await ScannerImageProcessingService.instance.applyFilter(
          inputPath: croppedFile.path,
          filter: _currentFilter,
          outputPath: filterOutPath,
        );

        finalImagePath = filteredFile.path;
      }

      final scannedPage = ScannedPageModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        originalImagePath: _currentOriginalPath,
        processedImagePath: finalImagePath,
        currentFilter: _currentFilter,
        rotationDegrees: _rotationDegrees,
        normalizedCropRect: _cropRect,
      );

      if (mounted) {
        Navigator.pop(context, scannedPage);
      }
    } catch (e) {
      debugPrint('[ScanToPdfEditorView] Commit error: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Failed to process page: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF131018) : const Color(0xFF1E1A24),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          tooltip: 'Retake',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Page ${widget.pageNumber} • Crop & Enhance',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
            tooltip: 'Rotate 90°',
            onPressed: _isProcessing ? null : _rotatePage,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Reset Crop',
            onPressed: () {
              setState(() {
                _cropRect = const Rect.fromLTWH(0.04, 0.04, 0.92, 0.92);
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Interactive Cropping Canvas
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _buildInteractiveCropArea(),
                ),
              ),

              // 2. Aspect Ratio Presets Bar
              _buildPresetsBar(),

              // 3. Filters Selector Bar
              _buildFilterSelectorBar(),

              // 4. Bottom Action CTA Bar
              _buildBottomAction(),
            ],
          ),

          // Processing Loading Overlay
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF261F33),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF9D65C9)),
                      const SizedBox(height: 16),
                      Text(
                        _processingMessage,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInteractiveCropArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth;
        final double maxH = constraints.maxHeight;

        final double imgAspect = _imageWidth / _imageHeight;
        final double containerAspect = maxW / maxH;

        double renderW;
        double renderH;

        if (imgAspect > containerAspect) {
          renderW = maxW;
          renderH = maxW / imgAspect;
        } else {
          renderH = maxH;
          renderW = maxH * imgAspect;
        }

        return Center(
          child: SizedBox(
            width: renderW,
            height: renderH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Rendered Document Image Preview
                Positioned.fill(
                  child: Image.file(
                    File(_currentProcessedPath),
                    fit: BoxFit.fill,
                  ),
                ),

                // Dark Mask outside the Crop Rectangle
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CropMaskPainter(cropRect: _cropRect),
                  ),
                ),

                // Crop Boundary Frame with Grid
                Positioned(
                  left: _cropRect.left * renderW,
                  top: _cropRect.top * renderH,
                  width: _cropRect.width * renderW,
                  height: _cropRect.height * renderH,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF9D65C9),
                        width: 2,
                      ),
                    ),
                    child: CustomPaint(
                      painter: _RuleOfThirdsPainter(),
                    ),
                  ),
                ),

                // Touch / Pan Gesture Recognizer
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanDown: (details) {
                      final localPos = details.localPosition;
                      _activeHandle = _detectHandle(localPos, renderW, renderH);
                      _lastPanPosition = localPos;
                    },
                    onPanUpdate: (details) {
                      if (_activeHandle == _ActiveCropHandle.none ||
                          _lastPanPosition == null) {
                        return;
                      }

                      final dx = (details.localPosition.dx - _lastPanPosition!.dx) / renderW;
                      final dy = (details.localPosition.dy - _lastPanPosition!.dy) / renderH;
                      _lastPanPosition = details.localPosition;

                      setState(() {
                        _updateCropRect(dx, dy);
                      });
                    },
                    onPanEnd: (_) {
                      _activeHandle = _ActiveCropHandle.none;
                      _lastPanPosition = null;
                    },
                  ),
                ),

                // Corner Handles UI Visuals
                _buildHandleMarker(
                  x: _cropRect.left * renderW,
                  y: _cropRect.top * renderH,
                  alignment: Alignment.topLeft,
                ),
                _buildHandleMarker(
                  x: _cropRect.right * renderW,
                  y: _cropRect.top * renderH,
                  alignment: Alignment.topRight,
                ),
                _buildHandleMarker(
                  x: _cropRect.left * renderW,
                  y: _cropRect.bottom * renderH,
                  alignment: Alignment.bottomLeft,
                ),
                _buildHandleMarker(
                  x: _cropRect.right * renderW,
                  y: _cropRect.bottom * renderH,
                  alignment: Alignment.bottomRight,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHandleMarker({
    required double x,
    required double y,
    required Alignment alignment,
  }) {
    return Positioned(
      left: x - 12,
      top: y - 12,
      child: IgnorePointer(
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF7046A8), width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _ActiveCropHandle _detectHandle(Offset pos, double renderW, double renderH) {
    const touchRadius = 32.0;

    final cropL = _cropRect.left * renderW;
    final cropR = _cropRect.right * renderW;
    final cropT = _cropRect.top * renderH;
    final cropB = _cropRect.bottom * renderH;

    // Check corners first
    if ((pos - Offset(cropL, cropT)).distance <= touchRadius) {
      return _ActiveCropHandle.topLeft;
    }
    if ((pos - Offset(cropR, cropT)).distance <= touchRadius) {
      return _ActiveCropHandle.topRight;
    }
    if ((pos - Offset(cropL, cropB)).distance <= touchRadius) {
      return _ActiveCropHandle.bottomLeft;
    }
    if ((pos - Offset(cropR, cropB)).distance <= touchRadius) {
      return _ActiveCropHandle.bottomRight;
    }

    // Check edges
    if ((pos.dy - cropT).abs() <= touchRadius && pos.dx >= cropL && pos.dx <= cropR) {
      return _ActiveCropHandle.topEdge;
    }
    if ((pos.dy - cropB).abs() <= touchRadius && pos.dx >= cropL && pos.dx <= cropR) {
      return _ActiveCropHandle.bottomEdge;
    }
    if ((pos.dx - cropL).abs() <= touchRadius && pos.dy >= cropT && pos.dy <= cropB) {
      return _ActiveCropHandle.leftEdge;
    }
    if ((pos.dx - cropR).abs() <= touchRadius && pos.dy >= cropT && pos.dy <= cropB) {
      return _ActiveCropHandle.rightEdge;
    }

    // Inside box -> pan center
    if (_cropRect.contains(Offset(pos.dx / renderW, pos.dy / renderH))) {
      return _ActiveCropHandle.center;
    }

    return _ActiveCropHandle.none;
  }

  void _updateCropRect(double dx, double dy) {
    const minSize = 0.08;

    double l = _cropRect.left;
    double t = _cropRect.top;
    double r = _cropRect.right;
    double b = _cropRect.bottom;

    switch (_activeHandle) {
      case _ActiveCropHandle.topLeft:
        l = (l + dx).clamp(0.0, r - minSize);
        t = (t + dy).clamp(0.0, b - minSize);
        break;
      case _ActiveCropHandle.topRight:
        r = (r + dx).clamp(l + minSize, 1.0);
        t = (t + dy).clamp(0.0, b - minSize);
        break;
      case _ActiveCropHandle.bottomLeft:
        l = (l + dx).clamp(0.0, r - minSize);
        b = (b + dy).clamp(t + minSize, 1.0);
        break;
      case _ActiveCropHandle.bottomRight:
        r = (r + dx).clamp(l + minSize, 1.0);
        b = (b + dy).clamp(t + minSize, 1.0);
        break;
      case _ActiveCropHandle.topEdge:
        t = (t + dy).clamp(0.0, b - minSize);
        break;
      case _ActiveCropHandle.bottomEdge:
        b = (b + dy).clamp(t + minSize, 1.0);
        break;
      case _ActiveCropHandle.leftEdge:
        l = (l + dx).clamp(0.0, r - minSize);
        break;
      case _ActiveCropHandle.rightEdge:
        r = (r + dx).clamp(l + minSize, 1.0);
        break;
      case _ActiveCropHandle.center:
        final w = r - l;
        final h = b - t;
        l = (l + dx).clamp(0.0, 1.0 - w);
        t = (t + dy).clamp(0.0, 1.0 - h);
        r = l + w;
        b = t + h;
        break;
      case _ActiveCropHandle.none:
        break;
    }

    _cropRect = Rect.fromLTRB(l, t, r, b);
  }

  Widget _buildPresetsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPresetChip('A4 Document', Icons.description_outlined, _presetA4),
          const SizedBox(width: 8),
          _buildPresetChip('Full Page', Icons.fullscreen_rounded, _presetFull),
          const SizedBox(width: 8),
          _buildPresetChip('ID / Card', Icons.badge_outlined, _presetCard),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFFD6BBFB)),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSelectorBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF261F33),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: DocumentFilterType.values.map((filter) {
          final isSelected = _currentFilter == filter;

          return Expanded(
            child: InkWell(
              onTap: _isProcessing ? null : () => _applyFilter(filter),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF7046A8) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  filter.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomAction() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _isProcessing ? null : _commitPageAndReturn,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'Accept Page',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter rendering dark mask outside the crop boundaries
class _CropMaskPainter extends CustomPainter {
  final Rect cropRect;

  _CropMaskPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.58)
      ..style = PaintingStyle.fill;

    final cropPx = Rect.fromLTRB(
      cropRect.left * size.width,
      cropRect.top * size.height,
      cropRect.right * size.width,
      cropRect.bottom * size.height,
    );

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropPx)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CropMaskPainter oldDelegate) =>
      oldDelegate.cropRect != cropRect;
}

/// Custom painter rendering subtle rule-of-thirds grid inside the crop frame
class _RuleOfThirdsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 1.0;

    // Vertical lines
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );

    // Horizontal lines
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
