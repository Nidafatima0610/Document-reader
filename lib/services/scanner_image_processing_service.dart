import 'dart:io';
import 'dart:ui';
import 'package:all_documents_reader/models/scanned_page_model.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Pure-Dart service performing real pixel-level image processing for document scanning
class ScannerImageProcessingService {
  ScannerImageProcessingService._internal();
  static final ScannerImageProcessingService instance =
      ScannerImageProcessingService._internal();
  factory ScannerImageProcessingService() => instance;

  /// Applies document enhancement filters to produce real transformed output
  Future<File> applyFilter({
    required String inputPath,
    required DocumentFilterType filter,
    required String outputPath,
  }) async {
    final inputFile = File(inputPath);
    if (!inputFile.existsSync()) {
      throw FileSystemException('Input image file not found', inputPath);
    }

    if (filter == DocumentFilterType.original) {
      // Direct copy preserves untouched original pixels
      return inputFile.copy(outputPath);
    }

    final Uint8List bytes = await inputFile.readAsBytes();
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Failed to decode image data.');
    }

    img.Image processed = decoded;

    switch (filter) {
      case DocumentFilterType.original:
        break;

      case DocumentFilterType.grayscale:
        processed = img.grayscale(processed);
        break;

      case DocumentFilterType.blackAndWhite:
        // 1. Convert to grayscale first
        processed = img.grayscale(processed);
        // 2. High-contrast document binarization (dark text on white paper)
        // Apply contrast stretch and thresholding
        processed = img.contrast(processed, contrast: 150);
        for (final pixel in processed) {
          final num lum = pixel.luminanceNormalized;
          final int val = lum > 0.52 ? 255 : 0;
          pixel.r = val;
          pixel.g = val;
          pixel.b = val;
        }
        break;

      case DocumentFilterType.enhanced:
        // Magic color enhancement: clean paper background and sharpen dark text
        processed = img.contrast(processed, contrast: 135);
        processed = img.adjustColor(processed, brightness: 1.08, saturation: 1.1);
        break;
    }

    final Uint8List encodedBytes = Uint8List.fromList(img.encodeJpg(processed, quality: 92));
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(encodedBytes, flush: true);
    return outputFile;
  }

  /// Crops image using normalized coordinates (0.0 to 1.0 range)
  Future<File> cropImage({
    required String inputPath,
    required Rect normalizedRect,
    required String outputPath,
  }) async {
    final inputFile = File(inputPath);
    if (!inputFile.existsSync()) {
      throw FileSystemException('Input image file not found', inputPath);
    }

    final Uint8List bytes = await inputFile.readAsBytes();
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Failed to decode image for cropping.');
    }

    // Clamp normalized bounds
    final leftNorm = normalizedRect.left.clamp(0.0, 1.0);
    final topNorm = normalizedRect.top.clamp(0.0, 1.0);
    final widthNorm = normalizedRect.width.clamp(0.05, 1.0 - leftNorm);
    final heightNorm = normalizedRect.height.clamp(0.05, 1.0 - topNorm);

    final int x = (leftNorm * decoded.width).round().clamp(0, decoded.width - 1);
    final int y = (topNorm * decoded.height).round().clamp(0, decoded.height - 1);
    final int w = (widthNorm * decoded.width).round().clamp(1, decoded.width - x);
    final int h = (heightNorm * decoded.height).round().clamp(1, decoded.height - y);

    final img.Image cropped = img.copyCrop(
      decoded,
      x: x,
      y: y,
      width: w,
      height: h,
    );

    final Uint8List encodedBytes = Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(encodedBytes, flush: true);
    return outputFile;
  }

  /// Rotates image by specified clockwise degrees (90, 180, 270)
  Future<File> rotateImage({
    required String inputPath,
    required int degrees,
    required String outputPath,
  }) async {
    final inputFile = File(inputPath);
    if (!inputFile.existsSync()) {
      throw FileSystemException('Input image file not found', inputPath);
    }

    final Uint8List bytes = await inputFile.readAsBytes();
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Failed to decode image for rotation.');
    }

    final img.Image rotated = img.copyRotate(decoded, angle: degrees);
    final Uint8List encodedBytes = Uint8List.fromList(img.encodeJpg(rotated, quality: 92));
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(encodedBytes, flush: true);
    return outputFile;
  }
}
