import 'dart:io';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

enum DocumentSectionType {
  title,
  heading1,
  heading2,
  paragraph,
  bulletList,
  table,
  divider,
}

class FormatterSection {
  final String id;
  DocumentSectionType type;
  String text;
  List<String> listItems;
  List<List<String>> tableData;
  double fontSize;
  TextAlign alignment;

  FormatterSection({
    required this.id,
    required this.type,
    this.text = '',
    this.listItems = const [],
    this.tableData = const [],
    this.fontSize = 12.0,
    this.alignment = TextAlign.left,
  });
}

class SmartFormatterOptions {
  final String documentTitle;
  final String? subtitle;
  final String? author;
  final bool includeDate;
  final double margin;

  const SmartFormatterOptions({
    this.documentTitle = 'Document',
    this.subtitle,
    this.author,
    this.includeDate = true,
    this.margin = 36.0,
  });
}

class SmartDocumentFormatterService {
  SmartDocumentFormatterService._internal();
  static final SmartDocumentFormatterService instance = SmartDocumentFormatterService._internal();
  factory SmartDocumentFormatterService() => instance;

  /// Generates a structured multi-page PDF with consistent typography,
  /// tables via PdfGrid, headings, lists, and safe auto-pagination.
  Future<PdfOperationResult> generateFormattedPdf({
    required List<FormatterSection> sections,
    SmartFormatterOptions options = const SmartFormatterOptions(),
    String? customFileName,
    Directory? outputDirectory,
  }) async {
    final doc = PdfDocument();

    try {
      doc.pageSettings.margins.all = options.margin;
      doc.pageSettings.size = PdfPageSize.a4;

      final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
      final h1Font = PdfStandardFont(PdfFontFamily.helvetica, 15, style: PdfFontStyle.bold);
      final h2Font = PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold);
      final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
      final metaFont = PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.italic);

      PdfPage page = doc.pages.add();
      double currentY = 0;
      final pageWidth = page.getClientSize().width;
      final pageHeight = page.getClientSize().height;

      // 1. Document Title
      if (options.documentTitle.isNotEmpty) {
        final titleElement = PdfTextElement(
          text: options.documentTitle,
          font: titleFont,
          brush: PdfSolidBrush(PdfColor(45, 36, 53)),
        );
        final titleRes = titleElement.draw(
          page: page,
          bounds: Rect.fromLTWH(0, currentY, pageWidth, pageHeight - currentY),
          format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
        );
        if (titleRes != null) {
          page = titleRes.page;
          currentY = titleRes.bounds.bottom + 6;
        }

        // Subtitle / Author / Date
        final metaParts = <String>[];
        if (options.subtitle != null && options.subtitle!.isNotEmpty) {
          metaParts.add(options.subtitle!);
        }
        if (options.author != null && options.author!.isNotEmpty) {
          metaParts.add('Author: ${options.author}');
        }
        if (options.includeDate) {
          metaParts.add('Date: ${DateTime.now().toLocal().toString().split(' ')[0]}');
        }
        if (metaParts.isNotEmpty) {
          final metaElement = PdfTextElement(
            text: metaParts.join('  •  '),
            font: metaFont,
            brush: PdfSolidBrush(PdfColor(110, 100, 125)),
          );
          final metaRes = metaElement.draw(
            page: page,
            bounds: Rect.fromLTWH(0, currentY, pageWidth, pageHeight - currentY),
            format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
          );
          if (metaRes != null) {
            page = metaRes.page;
            currentY = metaRes.bounds.bottom + 8;
          }
        }

        // Stylish Divider line
        page.graphics.drawLine(
          PdfPen(PdfColor(112, 70, 168), width: 1.5),
          Offset(0, currentY),
          Offset(pageWidth, currentY),
        );
        currentY += 14;
      }

      // 2. Render Sections
      for (final sec in sections) {
        // Prevent orphan headings at the very bottom of the page
        if ((sec.type == DocumentSectionType.heading1 || sec.type == DocumentSectionType.heading2 || sec.type == DocumentSectionType.title) &&
            currentY > pageHeight - 55) {
          page = doc.pages.add();
          currentY = 0;
        } else if (currentY > pageHeight - 35) {
          page = doc.pages.add();
          currentY = 0;
        }

        switch (sec.type) {
          case DocumentSectionType.title:
            final titleEl = PdfTextElement(
              text: sec.text,
              font: titleFont,
              brush: PdfSolidBrush(PdfColor(45, 36, 53)),
            );
            final res = titleEl.draw(
              page: page,
              bounds: Rect.fromLTWH(0, currentY, pageWidth, pageHeight - currentY),
              format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
            );
            if (res != null) {
              page = res.page;
              currentY = res.bounds.bottom + 12;
            }
            break;

          case DocumentSectionType.heading1:
            currentY += 4;
            final h1El = PdfTextElement(
              text: sec.text,
              font: h1Font,
              brush: PdfSolidBrush(PdfColor(112, 70, 168)),
            );
            final res = h1El.draw(
              page: page,
              bounds: Rect.fromLTWH(0, currentY, pageWidth, pageHeight - currentY),
              format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
            );
            if (res != null) {
              page = res.page;
              currentY = res.bounds.bottom + 8;
            }
            break;

          case DocumentSectionType.heading2:
            currentY += 2;
            final h2El = PdfTextElement(
              text: sec.text,
              font: h2Font,
              brush: PdfSolidBrush(PdfColor(60, 50, 70)),
            );
            final res = h2El.draw(
              page: page,
              bounds: Rect.fromLTWH(0, currentY, pageWidth, pageHeight - currentY),
              format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
            );
            if (res != null) {
              page = res.page;
              currentY = res.bounds.bottom + 6;
            }
            break;

          case DocumentSectionType.paragraph:
            final textElement = PdfTextElement(
              text: sec.text,
              font: bodyFont,
              brush: PdfSolidBrush(PdfColor(33, 33, 33)),
              format: PdfStringFormat(lineSpacing: 3),
            );
            final layoutResult = textElement.draw(
              page: page,
              bounds: Rect.fromLTWH(0, currentY, pageWidth, pageHeight - currentY),
              format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
            );
            if (layoutResult != null) {
              page = layoutResult.page;
              currentY = layoutResult.bounds.bottom + 12;
            }
            break;

          case DocumentSectionType.bulletList:
            for (final item in sec.listItems) {
              if (currentY > pageHeight - 30) {
                page = doc.pages.add();
                currentY = 0;
              }
              // Draw bullet symbol
              page.graphics.drawString(
                '•',
                bodyFont,
                brush: PdfSolidBrush(PdfColor(112, 70, 168)),
                bounds: Rect.fromLTWH(6, currentY, 15, 16),
              );
              // Draw text
              final itemEl = PdfTextElement(
                text: item,
                font: bodyFont,
                brush: PdfSolidBrush(PdfColor(33, 33, 33)),
              );
              final itemRes = itemEl.draw(
                page: page,
                bounds: Rect.fromLTWH(22, currentY, pageWidth - 22, pageHeight - currentY),
                format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
              );
              if (itemRes != null) {
                page = itemRes.page;
                currentY = itemRes.bounds.bottom + 4;
              }
            }
            currentY += 8;
            break;

          case DocumentSectionType.table:
            if (sec.tableData.isNotEmpty) {
              final grid = PdfGrid();
              final colCount = sec.tableData.first.length;
              grid.columns.add(count: colCount);

              // Styling
              grid.style = PdfGridStyle(
                cellPadding: PdfPaddings(left: 6, top: 5, right: 6, bottom: 5),
                font: bodyFont,
              );

              // Header Row
              final headerRow = grid.headers.add(1)[0];
              headerRow.style = PdfGridRowStyle(
                backgroundBrush: PdfSolidBrush(PdfColor(112, 70, 168)),
                textBrush: PdfSolidBrush(PdfColor(255, 255, 255)),
                font: PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold),
              );

              for (int c = 0; c < colCount; c++) {
                headerRow.cells[c].value = sec.tableData.first[c];
              }

              // Data Rows
              for (int r = 1; r < sec.tableData.length; r++) {
                final row = grid.rows.add();
                if (r.isEven) {
                  row.style = PdfGridRowStyle(
                    backgroundBrush: PdfSolidBrush(PdfColor(248, 246, 252)),
                  );
                }
                for (int c = 0; c < colCount; c++) {
                  row.cells[c].value = sec.tableData[r][c];
                }
              }

              // Draw table with automatic pagination
              final gridResult = grid.draw(
                page: page,
                bounds: Rect.fromLTWH(0, currentY, pageWidth, pageHeight - currentY),
                format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
              );

              if (gridResult != null) {
                page = gridResult.page;
                currentY = gridResult.bounds.bottom + 14;
              }
            }
            break;

          case DocumentSectionType.divider:
            currentY += 4;
            page.graphics.drawLine(
              PdfPen(PdfColor(220, 215, 230), width: 0.8),
              Offset(0, currentY),
              Offset(pageWidth, currentY),
            );
            currentY += 12;
            break;
        }
      }

      final pdfBytes = await doc.save();

      // Resolve output path
      Directory saveDir;
      if (outputDirectory != null) {
        saveDir = outputDirectory;
      } else {
        saveDir = await DocumentsStorageService.instance.getAppDocumentsDirectory();
      }

      if (!saveDir.existsSync()) {
        await saveDir.create(recursive: true);
      }

      String baseName = customFileName?.trim() ?? '';
      if (baseName.isEmpty) {
        final now = DateTime.now();
        final stamp =
            '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
        baseName = 'Formatted_Doc_$stamp.pdf';
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
