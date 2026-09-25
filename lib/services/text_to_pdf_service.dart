import 'dart:io';
import 'dart:ui';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Configuration options for text-to-pdf generation
class TextToPdfOptions {
  final String? title;
  final double fontSize;
  final bool includeDate;
  final double margin;

  const TextToPdfOptions({
    this.title,
    this.fontSize = 12.0,
    this.includeDate = true,
    this.margin = 36.0, // 0.5 inch margins
  });
}

/// Dedicated service for converting text notes into formatted multi-page PDFs
class TextToPdfService {
  TextToPdfService._internal();
  static final TextToPdfService instance = TextToPdfService._internal();
  factory TextToPdfService() => instance;

  /// Generates a clean, paginated PDF document from plain text
  Future<PdfOperationResult> generatePdfFromText({
    required String text,
    TextToPdfOptions options = const TextToPdfOptions(),
    String? customFileName,
    Directory? outputDirectory,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      throw ArgumentError('Text content cannot be empty.');
    }

    final doc = PdfDocument();

    try {
      doc.pageSettings.margins.all = options.margin;
      doc.pageSettings.size = PdfPageSize.a4;

      final PdfFont titleFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        18,
        style: PdfFontStyle.bold,
      );
      final PdfFont bodyFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        options.fontSize,
      );
      final PdfFont metaFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        9,
        style: PdfFontStyle.italic,
      );

      PdfPage page = doc.pages.add();
      double currentY = 0;
      final pageWidth = page.getClientSize().width;

      // Optional Title
      if (options.title != null && options.title!.trim().isNotEmpty) {
        final title = options.title!.trim();
        page.graphics.drawString(
          title,
          titleFont,
          brush: PdfSolidBrush(PdfColor(45, 36, 53)),
          bounds: Rect.fromLTWH(0, currentY, pageWidth, 28),
        );
        currentY += 32;

        // Optional creation date subtitle
        if (options.includeDate) {
          final dateStr = 'Generated: ${DateTime.now().toLocal().toString().split('.')[0]}';
          page.graphics.drawString(
            dateStr,
            metaFont,
            brush: PdfSolidBrush(PdfColor(108, 99, 116)),
            bounds: Rect.fromLTWH(0, currentY, pageWidth, 16),
          );
          currentY += 20;
        }

        // Horizontal divider line
        page.graphics.drawLine(
          PdfPen(PdfColor(220, 215, 230), width: 1),
          Offset(0, currentY),
          Offset(pageWidth, currentY),
        );
        currentY += 16;
      } else if (options.includeDate) {
        final dateStr = 'Date: ${DateTime.now().toLocal().toString().split('.')[0]}';
        page.graphics.drawString(
          dateStr,
          metaFont,
          brush: PdfSolidBrush(PdfColor(120, 120, 120)),
          bounds: Rect.fromLTWH(0, currentY, pageWidth, 16),
        );
        currentY += 20;
      }

      // Draw flowing text with auto-pagination
      final PdfTextElement textElement = PdfTextElement(
        text: cleanText,
        font: bodyFont,
        brush: PdfSolidBrush(PdfColor(33, 33, 33)),
        format: PdfStringFormat(lineSpacing: 4),
      );

      final layoutFormat = PdfLayoutFormat(
        layoutType: PdfLayoutType.paginate,
      );

      textElement.draw(
        page: page,
        bounds: Rect.fromLTWH(
          0,
          currentY,
          pageWidth,
          page.getClientSize().height - currentY,
        ),
        format: layoutFormat,
      );

      final pdfBytes = await doc.save();

      // Resolve output path
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
        baseName = 'Note_to_PDF_$stamp.pdf';
      } else if (!baseName.toLowerCase().endsWith('.pdf')) {
        baseName = '$baseName.pdf';
      }

      baseName = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      String finalName = baseName;
      String targetPath = '${saveDir.path}/$finalName';
      int counter = 1;
      while (File(targetPath).existsSync()) {
        final dotIndex = baseName.lastIndexOf('.');
        final namePart = dotIndex != -1 ? baseName.substring(0, dotIndex) : baseName;
        finalName = '${namePart}_$counter.pdf';
        targetPath = '${saveDir.path}/$finalName';
        counter++;
      }

      final File pdfFile = File(targetPath);
      await pdfFile.writeAsBytes(pdfBytes, flush: true);

      return PdfOperationResult(
        file: pdfFile,
        fileName: finalName,
        pageCount: doc.pages.count,
        fileSizeBytes: pdfBytes.length,
      );
    } finally {
      doc.dispose();
    }
  }
}
