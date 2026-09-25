import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_pdfviewer_platform_interface/pdfviewer_platform_interface.dart';

/// Result containing references to all image files generated from a PDF
class PdfToImageResult {
  final String originalPdfName;
  final Directory outputDirectory;
  final List<File> generatedFiles;
  final int pageCount;
  final int totalSizeBytes;

  const PdfToImageResult({
    required this.originalPdfName,
    required this.outputDirectory,
    required this.generatedFiles,
    required this.pageCount,
    required this.totalSizeBytes,
  });

  String get formattedTotalSize {
    if (totalSizeBytes < 1024) return '$totalSizeBytes B';
    if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Service dedicated to rendering PDF pages into high-resolution PNG image files
class PdfToImageService {
  PdfToImageService._internal();
  static final PdfToImageService instance = PdfToImageService._internal();
  factory PdfToImageService() => instance;

  /// Inspect a PDF to retrieve its total page count and dimensions
  Future<InspectedPdfInfo> inspectPdf(String filePath) {
    return PdfOperationsService.instance.inspectPdf(filePath);
  }

  /// Converts selected 1-based page numbers from a PDF into PNG images
  Future<PdfToImageResult> convertPdfToImages({
    required String pdfPath,
    required List<int> pageNumbers, // 1-based page indices
    double scale = 2.0, // 2.0x gives ~300 DPI high clarity
    Directory? outputDirectory,
    void Function(int current, int total, String status)? onProgress,
  }) async {
    final pdfFile = File(pdfPath);
    if (!pdfFile.existsSync()) {
      throw FileSystemException('PDF file not found at path', pdfPath);
    }

    final Uint8List pdfBytes = await pdfFile.readAsBytes();
    if (pdfBytes.isEmpty) {
      throw const FormatException('The selected PDF file is empty.');
    }

    // Validate page count with PdfDocument first
    final checkDoc = PdfDocument(inputBytes: pdfBytes);
    final totalDocPages = checkDoc.pages.count;
    checkDoc.dispose();

    if (totalDocPages == 0) {
      throw const FormatException('PDF has no pages.');
    }

    // Filter and sanitize requested page numbers
    final List<int> validPages = pageNumbers
        .where((p) => p >= 1 && p <= totalDocPages)
        .toSet()
        .toList()
      ..sort();

    if (validPages.isEmpty) {
      throw ArgumentError('No valid page numbers selected for conversion.');
    }

    // Resolve output directory
    final String pdfBaseName = pdfFile.path
        .split(RegExp(r'[/\\]'))
        .last
        .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    Directory targetDir;
    if (outputDirectory != null) {
      targetDir = Directory('${outputDirectory.path}/PDF_Images_${pdfBaseName}_$timestamp');
    } else {
      Directory baseDir;
      try {
        baseDir = await getApplicationDocumentsDirectory().timeout(
          const Duration(seconds: 1),
        );
      } catch (_) {
        baseDir = Directory.systemTemp;
      }
      targetDir = Directory('${baseDir.path}/PDF_Images_${pdfBaseName}_$timestamp');
    }

    if (!targetDir.existsSync()) {
      await targetDir.create(recursive: true);
    }

    final docId = 'pdf_to_img_${DateTime.now().microsecondsSinceEpoch}';
    final List<File> generatedFiles = [];
    int totalBytesAccumulated = 0;

    try {
      // 1. Initialize renderer
      await PdfViewerPlatform.instance.initializePdfRenderer(pdfBytes, docId);

      // 2. Query page dimensions
      final pagesHeight = await PdfViewerPlatform.instance.getPagesHeight(docId);
      final pagesWidth = await PdfViewerPlatform.instance.getPagesWidth(docId);

      for (int i = 0; i < validPages.length; i++) {
        final pageNum = validPages[i];
        final pageIdx = pageNum - 1;

        onProgress?.call(
          i + 1,
          validPages.length,
          'Rendering page $pageNum of $totalDocPages...',
        );

        double w = 595.0;
        double h = 842.0;
        if (pagesWidth != null && pageIdx < pagesWidth.length) {
          w = pagesWidth[pageIdx];
        }
        if (pagesHeight != null && pageIdx < pagesHeight.length) {
          h = pagesHeight[pageIdx];
        }

        final targetW = (w * scale).round().clamp(100, 4000);
        final targetH = (h * scale).round().clamp(100, 4000);

        final Uint8List? rawPixels = await PdfViewerPlatform.instance.getPage(
          pageNum,
          targetW,
          targetH,
          docId,
        );

        if (rawPixels == null || rawPixels.isEmpty) {
          debugPrint('Failed to render page $pageNum, skipping.');
          continue;
        }

        // Convert raw RGBA pixels to Flutter ui.Image
        ui.Image image;
        try {
          image = await _decodePixelsToImage(rawPixels, targetW, targetH);
        } catch (e) {
          debugPrint('Failed to decode pixels for page $pageNum: $e');
          continue;
        }

        // Encode ui.Image to lossless PNG byte data
        final ByteData? byteData = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        image.dispose();

        if (byteData == null) {
          debugPrint('Failed to encode PNG bytes for page $pageNum, skipping.');
          continue;
        }

        final Uint8List pngBytes = byteData.buffer.asUint8List();
        final padLength = totalDocPages > 99 ? 3 : 2;
        final pageNumberStr = pageNum.toString().padLeft(padLength, '0');
        final outFileName = '${pdfBaseName}_page_$pageNumberStr.png';
        final outFile = File('${targetDir.path}/$outFileName');

        await outFile.writeAsBytes(pngBytes, flush: true);
        generatedFiles.add(outFile);
        totalBytesAccumulated += pngBytes.length;

        // Register each generated image into DocumentsStorageService
        final docModel = DocumentsModel(
          name: outFileName,
          path: outFile.path,
          type: 'image',
          createdAt: DateTime.now(),
        );
        await DocumentsStorageService.instance.addDocument(docModel);

        // Yield to event loop to keep UI 60fps responsive
        await Future.delayed(Duration.zero);
      }

      return PdfToImageResult(
        originalPdfName: pdfFile.path.split(RegExp(r'[/\\]')).last,
        outputDirectory: targetDir,
        generatedFiles: generatedFiles,
        pageCount: generatedFiles.length,
        totalSizeBytes: totalBytesAccumulated,
      );
    } finally {
      try {
        await PdfViewerPlatform.instance.closeDocument(docId);
      } catch (_) {}
    }
  }

  Future<ui.Image> _decodePixelsToImage(Uint8List pixels, int width, int height) {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    try {
      ui.decodeImageFromPixels(
        pixels,
        width,
        height,
        ui.PixelFormat.rgba8888,
        (ui.Image img) {
          completer.complete(img);
        },
      );
    } catch (e) {
      completer.completeError(e);
    }
    return completer.future;
  }
}
