import 'dart:io';
import 'package:all_documents_reader/models/scanned_page_model.dart';
import 'package:all_documents_reader/views/scan_to_pdf_editor_view.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Production-ready camera screen for the Scan to PDF workflow.
/// Provides live camera preview, document reticle overlay, torch controls,
/// camera switching, and graceful permission & error handling.
class ScanToPdfCameraView extends StatefulWidget {
  final List<ScannedPageModel> existingPages;

  const ScanToPdfCameraView({
    super.key,
    this.existingPages = const [],
  });

  @override
  State<ScanToPdfCameraView> createState() => _ScanToPdfCameraViewState();
}

class _ScanToPdfCameraViewState extends State<ScanToPdfCameraView>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  bool _isInitializing = true;
  bool _isTakingPicture = false;
  bool _isPermissionDenied = false;
  bool _isPermissionPermanentlyDenied = false;
  String? _errorMessage;

  FlashMode _currentFlashMode = FlashMode.off;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCameraController(_cameras[_selectedCameraIndex]);
    }
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
      _isPermissionDenied = false;
      _isPermissionPermanentlyDenied = false;
    });

    // In unit / widget test environments, handle gracefully without native camera
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Camera preview is not available in unit test environment.';
      });
      return;
    }

    // 1. Check and request camera permission
    try {
      final status = await Permission.camera.status;
      if (!status.isGranted) {
        final requestResult = await Permission.camera.request();
        if (requestResult.isPermanentlyDenied) {
          if (mounted) {
            setState(() {
              _isInitializing = false;
              _isPermissionPermanentlyDenied = true;
            });
          }
          return;
        } else if (!requestResult.isGranted) {
          if (mounted) {
            setState(() {
              _isInitializing = false;
              _isPermissionDenied = true;
            });
          }
          return;
        }
      }

      // 2. Discover available device cameras
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _errorMessage = 'No camera sensors were found on this device.';
          });
        }
        return;
      }

      // Find back camera by default
      final backCameraIndex = _cameras.indexWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
      );
      _selectedCameraIndex = backCameraIndex != -1 ? backCameraIndex : 0;

      await _initCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('[ScanToPdfCameraView] Camera initialization error: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Failed to start camera: $e';
        });
      }
    }
  }

  Future<void> _initCameraController(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = controller;

    try {
      await controller.initialize();
      await controller.setFlashMode(_currentFlashMode);
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } on CameraException catch (e) {
      debugPrint('[ScanToPdfCameraView] CameraException: ${e.code} - ${e.description}');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          if (e.code == 'CameraAccessDenied' ||
              e.code == 'CameraAccessDeniedWithoutPrompt') {
            _isPermissionPermanentlyDenied =
                e.code == 'CameraAccessDeniedWithoutPrompt';
            _isPermissionDenied = true;
          } else {
            _errorMessage = 'Camera initialization failed (${e.code}).';
          }
        });
      }
    } catch (e) {
      debugPrint('[ScanToPdfCameraView] Unexpected error: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Could not initialize camera preview: $e';
        });
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    FlashMode nextMode;
    switch (_currentFlashMode) {
      case FlashMode.off:
        nextMode = FlashMode.torch;
        break;
      case FlashMode.torch:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
      default:
        nextMode = FlashMode.off;
        break;
    }

    try {
      await _controller!.setFlashMode(nextMode);
      setState(() {
        _currentFlashMode = nextMode;
      });
    } catch (e) {
      debugPrint('[ScanToPdfCameraView] Flash toggle failed: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _controller == null) return;

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    setState(() {
      _isInitializing = true;
    });

    await _controller?.dispose();
    await _initCameraController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isTakingPicture) {
      return;
    }

    try {
      setState(() {
        _isTakingPicture = true;
      });

      HapticFeedback.mediumImpact();
      final XFile photo = await controller.takePicture();

      if (!mounted) return;
      setState(() {
        _isTakingPicture = false;
      });

      // Proceed to Page Editor for manual crop and filters
      final newPage = await Navigator.push<ScannedPageModel>(
        context,
        MaterialPageRoute(
          builder: (context) => ScanToPdfEditorView(
            imagePath: photo.path,
            pageNumber: widget.existingPages.length + 1,
          ),
        ),
      );

      if (newPage != null && mounted) {
        Navigator.pop(context, newPage);
      }
    } catch (e) {
      debugPrint('[ScanToPdfCameraView] Capture error: $e');
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Failed to capture photo: $e'),
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (image != null && mounted) {
        final newPage = await Navigator.push<ScannedPageModel>(
          context,
          MaterialPageRoute(
            builder: (context) => ScanToPdfEditorView(
              imagePath: image.path,
              pageNumber: widget.existingPages.length + 1,
            ),
          ),
        );

        if (newPage != null && mounted) {
          Navigator.pop(context, newPage);
        }
      }
    } catch (e) {
      debugPrint('[ScanToPdfCameraView] Gallery pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Could not load gallery image: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview or Error/Permission Fallback
          _buildCameraContent(),

          // 2. Scanner Viewfinder Reticle (when camera is running)
          if (_controller != null && _controller!.value.isInitialized)
            _buildScannerReticle(),

          // 3. Top Action Bar (Back, Flash, Camera switch)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: _buildTopControls(),
            ),
          ),

          // 4. Bottom Controls (Gallery, Shutter Button, Pages count)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _buildBottomControls(),
            ),
          ),

          // 5. Capture Flash Animation
          if (_isTakingPicture)
            Container(color: Colors.white.withValues(alpha: 0.7)),
        ],
      ),
    );
  }

  Widget _buildCameraContent() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF9D65C9),
              strokeWidth: 3,
            ),
            SizedBox(height: 16),
            Text(
              'Initializing Camera...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    if (_isPermissionPermanentlyDenied || _isPermissionDenied) {
      return _buildPermissionDeniedView();
    }

    if (_errorMessage != null || _controller == null || !_controller!.value.isInitialized) {
      return _buildErrorView();
    }

    return Center(
      child: AspectRatio(
        aspectRatio: 1 / _controller!.value.aspectRatio,
        child: CameraPreview(_controller!),
      ),
    );
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF7046A8).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.no_photography_rounded,
                color: Color(0xFFD6BBFB),
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Camera Access Required',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isPermissionPermanentlyDenied
                  ? 'Camera permission has been permanently denied. Please enable camera access in Android Settings to scan physical documents.'
                  : 'All Documents Reader requires camera access to capture physical document pages.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            if (_isPermissionPermanentlyDenied)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7046A8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => openAppSettings(),
                icon: const Icon(Icons.settings_rounded, size: 20),
                label: const Text(
                  'Open App Settings',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7046A8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _initializeCamera,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text(
                  'Grant Permission',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_rounded, color: Colors.white70),
              label: const Text(
                'Choose from Gallery instead',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.orangeAccent,
              size: 54,
            ),
            const SizedBox(height: 16),
            const Text(
              'Camera Not Available',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unable to connect to camera hardware.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                  ),
                  onPressed: _initializeCamera,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7046A8),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: const Text('Pick Image'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerReticle() {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth * 0.86;
          final height = width * 1.35; // Aspect ratio close to A4 document

          return Center(
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  // Subtle transparent document guide box
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),

                  // High-contrast corner accents (Purple/White)
                  ..._buildCornerAccents(),

                  // Orientation hint banner
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF9D65C9).withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.crop_free_rounded,
                            color: Color(0xFFD6BBFB),
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Align document within frame',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildCornerAccents() {
    const double cornerLength = 26;
    const double cornerThickness = 4;
    const color = Color(0xFF9D65C9);

    return [
      // Top-Left
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: cornerLength,
          height: cornerThickness,
          decoration: const BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(8)),
          ),
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: cornerThickness,
          height: cornerLength,
          decoration: const BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(8)),
          ),
        ),
      ),

      // Top-Right
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: cornerLength,
          height: cornerThickness,
          decoration: const BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(topRight: Radius.circular(8)),
          ),
        ),
      ),
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: cornerThickness,
          height: cornerLength,
          decoration: const BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(topRight: Radius.circular(8)),
          ),
        ),
      ),

      // Bottom-Left
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: cornerLength,
          height: cornerThickness,
          decoration: const BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8)),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: cornerThickness,
          height: cornerLength,
          decoration: const BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8)),
          ),
        ),
      ),

      // Bottom-Right
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: cornerLength,
          height: cornerThickness,
          decoration: const BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(bottomRight: Radius.circular(8)),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: cornerThickness,
          height: cornerLength,
          decoration: const BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(bottomRight: Radius.circular(8)),
          ),
        ),
      ),
    ];
  }

  Widget _buildTopControls() {
    IconData flashIcon;
    Color flashColor = Colors.white;

    switch (_currentFlashMode) {
      case FlashMode.torch:
        flashIcon = Icons.flashlight_on_rounded;
        flashColor = Colors.amberAccent;
        break;
      case FlashMode.auto:
        flashIcon = Icons.flash_auto_rounded;
        flashColor = const Color(0xFFD6BBFB);
        break;
      case FlashMode.off:
      default:
        flashIcon = Icons.flash_off_rounded;
        flashColor = Colors.white70;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close / Back button
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.black45,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),

          Row(
            children: [
              // Flash Toggle
              if (_controller != null && _controller!.value.isInitialized)
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    shape: const CircleBorder(),
                  ),
                  icon: Icon(flashIcon, color: flashColor),
                  onPressed: _toggleFlash,
                  tooltip: 'Toggle Flash/Torch',
                ),

              const SizedBox(width: 8),

              // Switch Front/Back Camera
              if (_cameras.length > 1)
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    shape: const CircleBorder(),
                  ),
                  icon: const Icon(
                    Icons.flip_camera_ios_rounded,
                    color: Colors.white,
                  ),
                  onPressed: _switchCamera,
                  tooltip: 'Switch Camera',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.black87, Colors.black],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Gallery import button
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white12,
              padding: const EdgeInsets.all(14),
              shape: const CircleBorder(),
            ),
            icon: const Icon(
              Icons.photo_library_rounded,
              color: Colors.white,
              size: 26,
            ),
            tooltip: 'Import from Gallery',
            onPressed: _pickFromGallery,
          ),

          // Main Shutter / Capture Button
          GestureDetector(
            onTap: _takePicture,
            child: Container(
              width: 78,
              height: 78,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3.5),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isTakingPicture
                    ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
              ),
            ),
          ),

          // Pages Count / Session Review indicator
          if (widget.existingPages.isNotEmpty)
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF9D65C9), width: 2),
                      color: Colors.white12,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.file(
                      File(widget.existingPages.last.processedImagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.description_rounded,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.existingPages.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(width: 52),
        ],
      ),
    );
  }
}
