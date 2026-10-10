import 'dart:io';
import 'dart:ui';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Encapsulates metadata and file reference for a newly generated PDF
class PdfGenerationResult {
  final File file;
  final String fileName;
  final int pageCount;
  final int fileSizeBytes;

  const PdfGenerationResult({
    required this.file,
    required this.fileName,
    required this.pageCount,
    required this.fileSizeBytes,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    } else if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }
}

/// Service dedicated to generating high-quality PDFs from images
class PdfGeneratorService {
  PdfGeneratorService._internal();
  static final PdfGeneratorService instance = PdfGeneratorService._internal();
  factory PdfGeneratorService() => instance;

  /// Generates a PDF file from a list of image paths in the exact order given.
  /// Automatically tailors page dimensions to each image's native aspect ratio,
  /// preventing image distortion, awkward cropping, or letterboxing.
  Future<PdfGenerationResult> generatePdfFromImages({
    required List<String> imagePaths,
    String? customFileName,
    Directory? outputDirectory,
    bool studioQuality = false,
    void Function(int current, int total)? onProgress,
  }) async {
    if (imagePaths.isEmpty) {
      throw ArgumentError('At least one image path must be provided.');
    }

    final PdfDocument document = PdfDocument();
    document.compressionLevel = studioQuality
        ? PdfCompressionLevel.none
        : PdfCompressionLevel.normal;

    try {
      int processedCount = 0;
      for (int i = 0; i < imagePaths.length; i++) {
        final path = imagePaths[i];
        final file = File(path);

        if (!file.existsSync()) {
          debugPrint('Image file at "$path" not found, skipping.');
          continue;
        }

        final Uint8List bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          debugPrint('Image file at "$path" is empty, skipping.');
          continue;
        }

        final PdfBitmap bitmap = PdfBitmap(bytes);
        final double imgWidth = bitmap.width.toDouble();
        final double imgHeight = bitmap.height.toDouble();

        // Create a new section per page so dimensions match the image exactly
        final PdfSection section = document.sections!.add();
        section.pageSettings.margins.all = 0;
        section.pageSettings.size = Size(imgWidth, imgHeight);
        section.pageSettings.orientation = imgWidth > imgHeight
            ? PdfPageOrientation.landscape
            : PdfPageOrientation.portrait;

        final PdfPage page = section.pages.add();
        page.graphics.drawImage(
          bitmap,
          Rect.fromLTWH(0, 0, page.size.width, page.size.height),
        );

        processedCount++;
        onProgress?.call(processedCount, imagePaths.length);
      }

      if (processedCount == 0) {
        throw StateError(
          'None of the provided image paths contained valid image data.',
        );
      }

      // Save document to byte array
      final List<int> pdfBytes = await document.save();

      // Resolve output path in application documents directory or specified directory
      Directory saveDir;
      if (outputDirectory != null) {
        saveDir = outputDirectory;
      } else {
        saveDir = await DocumentsStorageService.instance.getAppDocumentsDirectory();
      }

      if (!saveDir.existsSync()) {
        await saveDir.create(recursive: true);
      }

      // Determine output file name
      String baseName = customFileName?.trim() ?? '';
      if (baseName.isEmpty) {
        final now = DateTime.now();
        final stamp =
            '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
        baseName = 'Images_to_PDF_$stamp.pdf';
      } else if (!baseName.toLowerCase().endsWith('.pdf')) {
        baseName = '$baseName.pdf';
      }

      // Sanitize special characters from filename
      baseName = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      // Ensure unique filename if already exists
      String finalName = baseName;
      String targetPath = '${saveDir.path}/$finalName';
      int counter = 1;
      while (File(targetPath).existsSync()) {
        final dotIndex = baseName.lastIndexOf('.');
        final namePart =
            dotIndex != -1 ? baseName.substring(0, dotIndex) : baseName;
        finalName = '${namePart}_$counter.pdf';
        targetPath = '${saveDir.path}/$finalName';
        counter++;
      }

      final File pdfFile = File(targetPath);
      await pdfFile.writeAsBytes(pdfBytes, flush: true);

      return PdfGenerationResult(
        file: pdfFile,
        fileName: finalName,
        pageCount: processedCount,
        fileSizeBytes: pdfBytes.length,
      );
    } finally {
      document.dispose();
    }
  }
}
