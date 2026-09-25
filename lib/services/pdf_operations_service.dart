import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Metadata holder for inspected PDF files
class InspectedPdfInfo {
  final String path;
  final String fileName;
  final int fileSizeBytes;
  final int pageCount;
  final List<Size> pageSizes;

  const InspectedPdfInfo({
    required this.path,
    required this.fileName,
    required this.fileSizeBytes,
    required this.pageCount,
    required this.pageSizes,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Result of a PDF text extraction operation
class PdfTextExtractionResult {
  final String text;
  final int pageCount;
  final bool isScannedOrEmpty;

  const PdfTextExtractionResult({
    required this.text,
    required this.pageCount,
    required this.isScannedOrEmpty,
  });
}

/// Result of a PDF compression operation
class PdfCompressionResult {
  final File file;
  final String fileName;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final bool isReduced;

  const PdfCompressionResult({
    required this.file,
    required this.fileName,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.isReduced,
  });

  int get bytesSaved =>
      originalSizeBytes > compressedSizeBytes
          ? originalSizeBytes - compressedSizeBytes
          : 0;

  double get savingsPercentage =>
      originalSizeBytes > 0 && isReduced
          ? (bytesSaved / originalSizeBytes) * 100
          : 0.0;
}

/// Generic outcome for PDF file manipulation operations
class PdfOperationResult {
  final File file;
  final String fileName;
  final int pageCount;
  final int fileSizeBytes;

  const PdfOperationResult({
    required this.file,
    required this.fileName,
    required this.pageCount,
    required this.fileSizeBytes,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Service providing robust, offline PDF manipulation tools
class PdfOperationsService {
  PdfOperationsService._internal();
  static final PdfOperationsService instance = PdfOperationsService._internal();
  factory PdfOperationsService() => instance;

  /// Inspect a PDF file and return its page count, sizes, and metadata
  Future<InspectedPdfInfo> inspectPdf(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('PDF file not found at path', filePath);
    }

    final int size = file.lengthSync();
    if (size == 0) {
      throw const FormatException('The selected PDF file is empty (0 bytes).');
    }

    final Uint8List bytes = await file.readAsBytes();
    PdfDocument? doc;
    try {
      doc = PdfDocument(inputBytes: bytes);
      final pageCount = doc.pages.count;
      if (pageCount == 0) {
        throw const FormatException('The PDF document contains no pages.');
      }

      final pageSizes = <Size>[];
      for (int i = 0; i < pageCount; i++) {
        final sz = doc.pages[i].size;
        pageSizes.add(Size(sz.width, sz.height));
      }

      final fileName = filePath.split(RegExp(r'[/\\]')).last;

      return InspectedPdfInfo(
        path: filePath,
        fileName: fileName,
        fileSizeBytes: size,
        pageCount: pageCount,
        pageSizes: pageSizes,
      );
    } catch (e) {
      if (e is FormatException || e is FileSystemException) rethrow;
      throw FormatException('Could not read PDF. File may be corrupted or password-protected: $e');
    } finally {
      doc?.dispose();
    }
  }

  /// Parses user-entered page range strings such as "1, 3-5, 8" into a sorted list of 1-based page indices
  List<int> parsePageRange(String text, int maxPages) {
    if (text.trim().isEmpty) return [];

    final Set<int> pages = {};
    final parts = text.split(RegExp(r'[,;]'));

    for (final rawPart in parts) {
      final part = rawPart.trim();
      if (part.isEmpty) continue;

      if (part.contains('-')) {
        final rangeParts = part.split('-');
        if (rangeParts.length == 2) {
          final start = int.tryParse(rangeParts[0].trim());
          final end = int.tryParse(rangeParts[1].trim());
          if (start != null && end != null) {
            final lower = start < end ? start : end;
            final upper = start < end ? end : start;
            for (int p = lower; p <= upper; p++) {
              if (p >= 1 && p <= maxPages) {
                pages.add(p);
              }
            }
          }
        }
      } else {
        final p = int.tryParse(part);
        if (p != null && p >= 1 && p <= maxPages) {
          pages.add(p);
        }
      }
    }

    final sorted = pages.toList()..sort();
    return sorted;
  }

  /// Extracts text from PDF using PdfTextExtractor.
  /// Handles scanned / image-only PDFs gracefully.
  Future<PdfTextExtractionResult> extractTextFromPdf({
    required String pdfPath,
    int? startPage, // 1-based
    int? endPage,   // 1-based
  }) async {
    final file = File(pdfPath);
    if (!file.existsSync()) {
      throw FileSystemException('PDF file not found', pdfPath);
    }

    final bytes = await file.readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);

    try {
      final pageCount = doc.pages.count;
      final extractor = PdfTextExtractor(doc);

      String extractedText = '';
      if (startPage != null && endPage != null) {
        final startIdx = (startPage - 1).clamp(0, pageCount - 1);
        final endIdx = (endPage - 1).clamp(0, pageCount - 1);
        extractedText = extractor.extractText(
          startPageIndex: startIdx,
          endPageIndex: endIdx,
        );
      } else {
        extractedText = extractor.extractText();
      }

      final isScanned = extractedText.trim().isEmpty;

      return PdfTextExtractionResult(
        text: extractedText,
        pageCount: pageCount,
        isScannedOrEmpty: isScanned,
      );
    } finally {
      doc.dispose();
    }
  }

  /// Merges multiple PDF files into one coherent PDF document, preserving original dimensions
  Future<PdfOperationResult> mergePdfs({
    required List<String> pdfPaths,
    String? customFileName,
    Directory? outputDirectory,
    void Function(int current, int total)? onProgress,
  }) async {
    if (pdfPaths.length < 2) {
      throw ArgumentError('At least two PDF files are required to merge.');
    }

    final newDoc = PdfDocument();
    int totalPages = 0;

    try {
      for (int fIndex = 0; fIndex < pdfPaths.length; fIndex++) {
        final path = pdfPaths[fIndex];
        final file = File(path);
        if (!file.existsSync()) continue;

        final bytes = await file.readAsBytes();
        final srcDoc = PdfDocument(inputBytes: bytes);

        for (int pIndex = 0; pIndex < srcDoc.pages.count; pIndex++) {
          final template = srcDoc.pages[pIndex].createTemplate();
          final section = newDoc.sections!.add();
          section.pageSettings.size = template.size;
          section.pageSettings.margins.all = 0;
          section.pages.add().graphics.drawPdfTemplate(template, Offset.zero);
          totalPages++;
        }

        srcDoc.dispose();
        onProgress?.call(fIndex + 1, pdfPaths.length);
      }

      if (totalPages == 0) {
        throw StateError('None of the provided PDFs contained readable pages.');
      }

      final pdfBytes = await newDoc.save();
      final outputFile = await _saveBytesToOutputFile(
        bytes: pdfBytes,
        customName: customFileName,
        defaultPrefix: 'Merged_PDF',
        extension: 'pdf',
        outputDirectory: outputDirectory,
      );

      return PdfOperationResult(
        file: outputFile,
        fileName: outputFile.path.split(RegExp(r'[/\\]')).last,
        pageCount: totalPages,
        fileSizeBytes: pdfBytes.length,
      );
    } finally {
      newDoc.dispose();
    }
  }

  /// Splits a PDF by extracting specific 1-based page numbers into a new PDF document
  Future<PdfOperationResult> splitPdf({
    required String pdfPath,
    required List<int> pages, // 1-based
    String? customFileName,
    Directory? outputDirectory,
  }) async {
    if (pages.isEmpty) {
      throw ArgumentError('At least one page must be selected to split.');
    }

    final file = File(pdfPath);
    if (!file.existsSync()) {
      throw FileSystemException('PDF file not found', pdfPath);
    }

    final bytes = await file.readAsBytes();
    final srcDoc = PdfDocument(inputBytes: bytes);
    final newDoc = PdfDocument();

    try {
      int extractedCount = 0;
      for (final pNum in pages) {
        final pIdx = pNum - 1;
        if (pIdx >= 0 && pIdx < srcDoc.pages.count) {
          final template = srcDoc.pages[pIdx].createTemplate();
          final section = newDoc.sections!.add();
          section.pageSettings.size = template.size;
          section.pageSettings.margins.all = 0;
          section.pages.add().graphics.drawPdfTemplate(template, Offset.zero);
          extractedCount++;
        }
      }

      if (extractedCount == 0) {
        throw ArgumentError('None of the selected pages are within the document.');
      }

      final pdfBytes = await newDoc.save();
      final outputFile = await _saveBytesToOutputFile(
        bytes: pdfBytes,
        customName: customFileName,
        defaultPrefix: 'Split_Pages',
        extension: 'pdf',
        outputDirectory: outputDirectory,
      );

      return PdfOperationResult(
        file: outputFile,
        fileName: outputFile.path.split(RegExp(r'[/\\]')).last,
        pageCount: extractedCount,
        fileSizeBytes: pdfBytes.length,
      );
    } finally {
      srcDoc.dispose();
      newDoc.dispose();
    }
  }

  /// Rotates all or selected 1-based pages of a PDF by 90, 180, or 270 degrees
  Future<PdfOperationResult> rotatePdf({
    required String pdfPath,
    required PdfPageRotateAngle angle,
    List<int>? targetPages, // 1-based; null or empty means all pages
    String? customFileName,
    Directory? outputDirectory,
  }) async {
    final file = File(pdfPath);
    if (!file.existsSync()) {
      throw FileSystemException('PDF file not found', pdfPath);
    }

    final bytes = await file.readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);

    try {
      final totalPages = doc.pages.count;
      final Set<int> targetSet = targetPages != null && targetPages.isNotEmpty
          ? targetPages.toSet()
          : Set.from(List.generate(totalPages, (i) => i + 1));

      for (int i = 0; i < totalPages; i++) {
        final pageNum = i + 1;
        if (targetSet.contains(pageNum)) {
          // Accumulate rotation
          final currentRotation = doc.pages[i].rotation;
          final newRotation = _addRotation(currentRotation, angle);
          doc.pages[i].rotation = newRotation;
        }
      }

      final pdfBytes = await doc.save();
      final outputFile = await _saveBytesToOutputFile(
        bytes: pdfBytes,
        customName: customFileName,
        defaultPrefix: 'Rotated_PDF',
        extension: 'pdf',
        outputDirectory: outputDirectory,
      );

      return PdfOperationResult(
        file: outputFile,
        fileName: outputFile.path.split(RegExp(r'[/\\]')).last,
        pageCount: totalPages,
        fileSizeBytes: pdfBytes.length,
      );
    } finally {
      doc.dispose();
    }
  }

  /// Reorders pages of a PDF based on the provided 1-based page sequence
  Future<PdfOperationResult> reorderPdfPages({
    required String pdfPath,
    required List<int> newPageOrder, // 1-based
    String? customFileName,
    Directory? outputDirectory,
  }) async {
    if (newPageOrder.isEmpty) {
      throw ArgumentError('New page order sequence cannot be empty.');
    }

    final file = File(pdfPath);
    if (!file.existsSync()) {
      throw FileSystemException('PDF file not found', pdfPath);
    }

    final bytes = await file.readAsBytes();
    final srcDoc = PdfDocument(inputBytes: bytes);
    final newDoc = PdfDocument();

    try {
      int added = 0;
      for (final pNum in newPageOrder) {
        final pIdx = pNum - 1;
        if (pIdx >= 0 && pIdx < srcDoc.pages.count) {
          final template = srcDoc.pages[pIdx].createTemplate();
          final section = newDoc.sections!.add();
          section.pageSettings.size = template.size;
          section.pageSettings.margins.all = 0;
          section.pages.add().graphics.drawPdfTemplate(template, Offset.zero);
          added++;
        }
      }

      if (added == 0) {
        throw ArgumentError('No valid pages found in the new page sequence.');
      }

      final pdfBytes = await newDoc.save();
      final outputFile = await _saveBytesToOutputFile(
        bytes: pdfBytes,
        customName: customFileName,
        defaultPrefix: 'Reordered_PDF',
        extension: 'pdf',
        outputDirectory: outputDirectory,
      );

      return PdfOperationResult(
        file: outputFile,
        fileName: outputFile.path.split(RegExp(r'[/\\]')).last,
        pageCount: added,
        fileSizeBytes: pdfBytes.length,
      );
    } finally {
      srcDoc.dispose();
      newDoc.dispose();
    }
  }

  /// Optimizes PDF streams and eliminates unreferenced revision objects.
  /// Measures real byte savings honestly.
  Future<PdfCompressionResult> compressPdf({
    required String pdfPath,
    String? customFileName,
    Directory? outputDirectory,
  }) async {
    final file = File(pdfPath);
    if (!file.existsSync()) {
      throw FileSystemException('PDF file not found', pdfPath);
    }

    final originalSize = file.lengthSync();
    final bytes = await file.readAsBytes();
    final srcDoc = PdfDocument(inputBytes: bytes);
    final optimizedDoc = PdfDocument();

    try {
      for (int i = 0; i < srcDoc.pages.count; i++) {
        final template = srcDoc.pages[i].createTemplate();
        final section = optimizedDoc.sections!.add();
        section.pageSettings.size = template.size;
        section.pageSettings.margins.all = 0;
        section.pages.add().graphics.drawPdfTemplate(template, Offset.zero);
      }

      final optimizedBytes = await optimizedDoc.save();
      final isReduced = optimizedBytes.length < originalSize;

      final outputFile = await _saveBytesToOutputFile(
        bytes: optimizedBytes,
        customName: customFileName,
        defaultPrefix: 'Compressed_PDF',
        extension: 'pdf',
        outputDirectory: outputDirectory,
      );

      return PdfCompressionResult(
        file: outputFile,
        fileName: outputFile.path.split(RegExp(r'[/\\]')).last,
        originalSizeBytes: originalSize,
        compressedSizeBytes: optimizedBytes.length,
        isReduced: isReduced,
      );
    } finally {
      srcDoc.dispose();
      optimizedDoc.dispose();
    }
  }

  // Helper for angular addition
  PdfPageRotateAngle _addRotation(PdfPageRotateAngle current, PdfPageRotateAngle add) {
    final currentDeg = _rotationToDegrees(current);
    final addDeg = _rotationToDegrees(add);
    final total = (currentDeg + addDeg) % 360;
    switch (total) {
      case 90:
        return PdfPageRotateAngle.rotateAngle90;
      case 180:
        return PdfPageRotateAngle.rotateAngle180;
      case 270:
        return PdfPageRotateAngle.rotateAngle270;
      default:
        return PdfPageRotateAngle.rotateAngle0;
    }
  }

  int _rotationToDegrees(PdfPageRotateAngle angle) {
    switch (angle) {
      case PdfPageRotateAngle.rotateAngle90:
        return 90;
      case PdfPageRotateAngle.rotateAngle180:
        return 180;
      case PdfPageRotateAngle.rotateAngle270:
        return 270;
      case PdfPageRotateAngle.rotateAngle0:
        return 0;
    }
  }

  /// Internal helper to resolve save directory, sanitize unique filename, and write bytes
  Future<File> _saveBytesToOutputFile({
    required List<int> bytes,
    String? customName,
    required String defaultPrefix,
    required String extension,
    Directory? outputDirectory,
  }) async {
    Directory saveDir;
    if (outputDirectory != null) {
      saveDir = outputDirectory;
    } else {
      try {
        saveDir = await getApplicationDocumentsDirectory().timeout(
          const Duration(seconds: 1),
        );
      } catch (e) {
        saveDir = Directory.systemTemp;
      }
    }

    if (!saveDir.existsSync()) {
      await saveDir.create(recursive: true);
    }

    String baseName = customName?.trim() ?? '';
    if (baseName.isEmpty) {
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      baseName = '${defaultPrefix}_$stamp.$extension';
    } else if (!baseName.toLowerCase().endsWith('.$extension')) {
      baseName = '$baseName.$extension';
    }

    baseName = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    String finalName = baseName;
    String targetPath = '${saveDir.path}/$finalName';
    int counter = 1;
    while (File(targetPath).existsSync()) {
      final dotIndex = baseName.lastIndexOf('.');
      final namePart = dotIndex != -1 ? baseName.substring(0, dotIndex) : baseName;
      finalName = '${namePart}_$counter.$extension';
      targetPath = '${saveDir.path}/$finalName';
      counter++;
    }

    final File resultFile = File(targetPath);
    await resultFile.writeAsBytes(bytes, flush: true);
    return resultFile;
  }
}
