import 'dart:io';
import 'package:all_documents_reader/services/scanner_image_processing_service.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Screen allowing the user to manually crop a scanned document page
class ManualCropView extends StatefulWidget {
  final String imagePath;
  final Widget? imagePreview;

  const ManualCropView({
    super.key,
    required this.imagePath,
    this.imagePreview,
  });

  @override
  State<ManualCropView> createState() => _ManualCropViewState();
}

enum _DragHandle {
  none,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  center,
}

class _ManualCropViewState extends State<ManualCropView> {
  // Normalized coordinates (0.0 to 1.0)
  Rect _cropRect = const Rect.fromLTWH(0.05, 0.05, 0.9, 0.9);
  _DragHandle _activeHandle = _DragHandle.none;
  Offset? _lastDragPosition;

  bool _isProcessing = false;
  double _imageWidth = 200;
  double _imageHeight = 200;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  @override
  void initState() {
    super.initState();
    _loadImageDimensions();
  }

  @override
  void dispose() {
    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
    }
    super.dispose();
  }

  void _loadImageDimensions() {
    if (widget.imagePreview != null) {
      _imageWidth = 200;
      _imageHeight = 200;
      return;
    }

    final file = File(widget.imagePath);
    if (!file.existsSync()) return;

    try {
      final bytes = file.readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        _imageWidth = decoded.width.toDouble();
        _imageHeight = decoded.height.toDouble();
        return;
      }
    } catch (_) {}

    _imageStream = FileImage(file).resolve(ImageConfiguration.empty);
    _imageStreamListener = ImageStreamListener((info, _) {
      if (mounted) {
        setState(() {
          _imageWidth = info.image.width.toDouble();
          _imageHeight = info.image.height.toDouble();
        });
      }
    });
    _imageStream!.addListener(_imageStreamListener!);
  }

  void _resetCrop() {
    setState(() {
      _cropRect = const Rect.fromLTWH(0.05, 0.05, 0.9, 0.9);
    });
  }

  void _setA4Aspect() {
    // Standard A4 aspect ratio is ~1 : 1.414 (portrait) or 1.414 : 1 (landscape)
    final isLandscape = _imageWidth > _imageHeight;
    final double targetAspect = isLandscape ? 1.414 : (1 / 1.414);

    setState(() {
      double w = 0.85;
      double h = w / targetAspect;
      if (h > 0.9) {
        h = 0.85;
        w = h * targetAspect;
      }
      final l = (1.0 - w) / 2;
      final t = (1.0 - h) / 2;
      _cropRect = Rect.fromLTWH(l.clamp(0.0, 1.0), t.clamp(0.0, 1.0), w, h);
    });
  }

  Future<void> _applyCrop() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final now = DateTime.now().microsecondsSinceEpoch;
      final parentDir = File(widget.imagePath).parent.path;
      final outPath = '$parentDir/cropped_$now.jpg';

      final croppedFile = await ScannerImageProcessingService.instance.cropImage(
        inputPath: widget.imagePath,
        normalizedRect: _cropRect,
        outputPath: outPath,
      );

      if (!mounted) return;
      Navigator.pop(context, croppedFile.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Failed to crop image: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Crop Document'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset Crop',
            onPressed: _resetCrop,
          ),
          IconButton(
            icon: const Icon(Icons.aspect_ratio_rounded),
            tooltip: 'A4 Document Ratio',
            onPressed: _setA4Aspect,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final imgW = _imageWidth;
                  final imgH = _imageHeight;

                  // Calculate letterbox / aspect-fit rect within layout container
                  final double screenAspect =
                      constraints.maxWidth / constraints.maxHeight;
                  final double imgAspect = imgW / imgH;

                  double displayW;
                  double displayH;
                  double offsetX = 0;
                  double offsetY = 0;

                  if (screenAspect > imgAspect) {
                    displayH = constraints.maxHeight;
                    displayW = displayH * imgAspect;
                    offsetX = (constraints.maxWidth - displayW) / 2;
                  } else {
                    displayW = constraints.maxWidth;
                    displayH = displayW / imgAspect;
                    offsetY = (constraints.maxHeight - displayH) / 2;
                  }

                  final displayRect = Rect.fromLTWH(
                    offsetX,
                    offsetY,
                    displayW,
                    displayH,
                  );

                  return GestureDetector(
                    onPanStart: (details) => _onPanStart(details, displayRect),
                    onPanUpdate: (details) =>
                        _onPanUpdate(details, displayRect),
                    onPanEnd: (_) => setState(() => _activeHandle = _DragHandle.none),
                    child: Stack(
                      children: [
                        Positioned.fromRect(
                          rect: displayRect,
                          child: widget.imagePreview ??
                              Image.file(
                                File(widget.imagePath),
                                fit: BoxFit.fill,
                              ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _CropOverlayPainter(
                              displayRect: displayRect,
                              cropRectNorm: _cropRect,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom action bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: const Color(0xFF1E1E1E),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    label: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7046A8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isProcessing ? null : _applyCrop,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 20),
                    label: const Text(
                      'Apply Crop',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onPanStart(DragStartDetails details, Rect displayRect) {
    final touchPos = details.localPosition;
    final cropPixelRect = Rect.fromLTWH(
      displayRect.left + _cropRect.left * displayRect.width,
      displayRect.top + _cropRect.top * displayRect.height,
      _cropRect.width * displayRect.width,
      _cropRect.height * displayRect.height,
    );

    const hitThreshold = 36.0;

    if ((touchPos - cropPixelRect.topLeft).distance < hitThreshold) {
      _activeHandle = _DragHandle.topLeft;
    } else if ((touchPos - cropPixelRect.topRight).distance < hitThreshold) {
      _activeHandle = _DragHandle.topRight;
    } else if ((touchPos - cropPixelRect.bottomLeft).distance < hitThreshold) {
      _activeHandle = _DragHandle.bottomLeft;
    } else if ((touchPos - cropPixelRect.bottomRight).distance < hitThreshold) {
      _activeHandle = _DragHandle.bottomRight;
    } else if (cropPixelRect.contains(touchPos)) {
      _activeHandle = _DragHandle.center;
    } else {
      _activeHandle = _DragHandle.none;
    }

    _lastDragPosition = touchPos;
  }

  void _onPanUpdate(DragUpdateDetails details, Rect displayRect) {
    if (_activeHandle == _DragHandle.none || _lastDragPosition == null) return;

    final currentPos = details.localPosition;
    final delta = currentPos - _lastDragPosition!;
    _lastDragPosition = currentPos;

    final double normDeltaX = delta.dx / displayRect.width;
    final double normDeltaY = delta.dy / displayRect.height;

    setState(() {
      double l = _cropRect.left;
      double t = _cropRect.top;
      double r = _cropRect.right;
      double b = _cropRect.bottom;

      switch (_activeHandle) {
        case _DragHandle.topLeft:
          l = (l + normDeltaX).clamp(0.0, r - 0.1);
          t = (t + normDeltaY).clamp(0.0, b - 0.1);
          break;
        case _DragHandle.topRight:
          r = (r + normDeltaX).clamp(l + 0.1, 1.0);
          t = (t + normDeltaY).clamp(0.0, b - 0.1);
          break;
        case _DragHandle.bottomLeft:
          l = (l + normDeltaX).clamp(0.0, r - 0.1);
          b = (b + normDeltaY).clamp(t + 0.1, 1.0);
          break;
        case _DragHandle.bottomRight:
          r = (r + normDeltaX).clamp(l + 0.1, 1.0);
          b = (b + normDeltaY).clamp(t + 0.1, 1.0);
          break;
        case _DragHandle.center:
          final double w = _cropRect.width;
          final double h = _cropRect.height;
          l = (l + normDeltaX).clamp(0.0, 1.0 - w);
          t = (t + normDeltaY).clamp(0.0, 1.0 - h);
          r = l + w;
          b = t + h;
          break;
        case _DragHandle.none:
          break;
      }

      _cropRect = Rect.fromLTRB(l, t, r, b);
    });
  }
}

class _CropOverlayPainter extends CustomPainter {
  final Rect displayRect;
  final Rect cropRectNorm;

  _CropOverlayPainter({
    required this.displayRect,
    required this.cropRectNorm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cropPixelRect = Rect.fromLTWH(
      displayRect.left + cropRectNorm.left * displayRect.width,
      displayRect.top + cropRectNorm.top * displayRect.height,
      cropRectNorm.width * displayRect.width,
      cropRectNorm.height * displayRect.height,
    );

    // 1. Dark Scrim Mask
    final scrimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    final scrimPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropPixelRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(scrimPath, scrimPaint);

    // 2. Crop Border
    final borderPaint = Paint()
      ..color = const Color(0xFF7046A8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(cropPixelRect, borderPaint);

    // 3. Rule of Thirds Grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;

    final thirdW = cropPixelRect.width / 3;
    final thirdH = cropPixelRect.height / 3;

    // Vertical grid lines
    canvas.drawLine(
      Offset(cropPixelRect.left + thirdW, cropPixelRect.top),
      Offset(cropPixelRect.left + thirdW, cropPixelRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropPixelRect.left + thirdW * 2, cropPixelRect.top),
      Offset(cropPixelRect.left + thirdW * 2, cropPixelRect.bottom),
      gridPaint,
    );

    // Horizontal grid lines
    canvas.drawLine(
      Offset(cropPixelRect.left, cropPixelRect.top + thirdH),
      Offset(cropPixelRect.right, cropPixelRect.top + thirdH),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropPixelRect.left, cropPixelRect.top + thirdH * 2),
      Offset(cropPixelRect.right, cropPixelRect.top + thirdH * 2),
      gridPaint,
    );

    // 4. Corner Handles
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleStroke = Paint()
      ..color = const Color(0xFF7046A8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    const radius = 10.0;
    final corners = [
      cropPixelRect.topLeft,
      cropPixelRect.topRight,
      cropPixelRect.bottomLeft,
      cropPixelRect.bottomRight,
    ];

    for (final corner in corners) {
      canvas.drawCircle(corner, radius, handlePaint);
      canvas.drawCircle(corner, radius, handleStroke);
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.displayRect != displayRect ||
        oldDelegate.cropRectNorm != cropRectNorm;
  }
}
