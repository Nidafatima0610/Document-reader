import 'dart:io';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

/// Structured outcome of an OCR recognition process
class OcrResult {
  final String text;
  final int lineCount;
  final int blockCount;
  final String imagePath;
  final bool isEmpty;

  const OcrResult({
    required this.text,
    required this.lineCount,
    required this.blockCount,
    required this.imagePath,
    required this.isEmpty,
  });
}

/// Service providing on-device Optical Character Recognition (OCR) for images
class OcrService {
  OcrService._internal();
  static final OcrService instance = OcrService._internal();
  factory OcrService() => instance;

  /// Recognizes textual content inside an image file using on-device ML Kit
  Future<OcrResult> recognizeTextFromImage(String imagePath) async {
    final file = File(imagePath);
    if (!file.existsSync()) {
      throw FileSystemException('Image file not found', imagePath);
    }

    final int size = file.lengthSync();
    if (size == 0) {
      throw const FormatException('Selected image file is empty (0 bytes).');
    }

    final InputImage inputImage = InputImage.fromFilePath(imagePath);
    final TextRecognizer recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final RecognizedText recognizedText = await recognizer.processImage(inputImage);
      final String rawText = recognizedText.text;

      int lineCount = 0;
      for (final block in recognizedText.blocks) {
        lineCount += block.lines.length;
      }

      return OcrResult(
        text: rawText,
        lineCount: lineCount,
        blockCount: recognizedText.blocks.length,
        imagePath: imagePath,
        isEmpty: rawText.trim().isEmpty,
      );
    } catch (e) {
      debugPrint('Error performing OCR: $e');
      // If running on desktop without mobile ML Kit binary
      if (e is MissingPluginException || e is UnimplementedError) {
        throw UnsupportedError(
          'On-device hardware ML Kit is supported natively on Android and iOS. '
          'To test on desktop, run on an Android/iOS emulator or connected device.',
        );
      }
      rethrow;
    } finally {
      await recognizer.close();
    }
  }

  /// Saves extracted text as a .txt document and registers with DocumentsStorageService
  Future<DocumentsModel> saveExtractedTextAsDocument({
    required String text,
    String? customFileName,
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
      } catch (_) {
        saveDir = Directory.systemTemp;
      }
    }

    if (!saveDir.existsSync()) {
      await saveDir.create(recursive: true);
    }

    String baseName = customFileName?.trim() ?? '';
    if (baseName.isEmpty) {
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      baseName = 'OCR_Text_$stamp.txt';
    } else if (!baseName.toLowerCase().endsWith('.txt')) {
      baseName = '$baseName.txt';
    }

    baseName = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    String finalName = baseName;
    String targetPath = '${saveDir.path}/$finalName';
    int counter = 1;
    while (File(targetPath).existsSync()) {
      final dotIndex = baseName.lastIndexOf('.');
      final namePart = dotIndex != -1 ? baseName.substring(0, dotIndex) : baseName;
      finalName = '${namePart}_$counter.txt';
      targetPath = '${saveDir.path}/$finalName';
      counter++;
    }

    final File txtFile = File(targetPath);
    await txtFile.writeAsString(text, flush: true);

    final docModel = DocumentsModel(
      name: finalName,
      path: txtFile.path,
      type: 'txt',
      createdAt: DateTime.now(),
    );

    await DocumentsStorageService.instance.addDocument(docModel);
    return docModel;
  }
}
