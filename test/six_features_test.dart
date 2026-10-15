import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:all_documents_reader/models/tool_item_model.dart';
import 'package:all_documents_reader/services/smart_document_formatter_service.dart';
import 'package:all_documents_reader/services/document_converter_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:all_documents_reader/services/tools_registry_service.dart';
import 'package:all_documents_reader/services/ocr_service.dart';
import 'package:all_documents_reader/services/document_save_service.dart';
import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('six_features_test_');
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // Helper to create a simple multi-page PDF in tempDir
  File createSamplePdf(String filename, int pageCount, {bool blank = false}) {
    final document = sf.PdfDocument();
    for (int i = 0; i < pageCount; i++) {
      final page = document.pages.add();
      if (!blank) {
        final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 16);
        page.graphics.drawString(
          'Page ${i + 1} of $pageCount\nSample Document Content for Testing',
          font,
          bounds: const Rect.fromLTWH(50, 50, 400, 100),
        );
      }
    }
    final file = File('${tempDir.path}/$filename');
    file.writeAsBytesSync(document.saveSync());
    document.dispose();
    return file;
  }

  group('Feature 1 & Tools Registry Integration', () {
    test('ToolsRegistryService registers all 4 newly introduced tools with proper metadata', () {
      final registry = ToolsRegistryService.instance;
      final allTools = registry.allRegisteredTools;

      final editorTool = allTools.firstWhere((t) => t.id == 'pdf_text_editor');
      expect(editorTool.title, 'PDF Text Editor');
      expect(editorTool.category, ToolCategory.managePdf);

      final formatterTool = allTools.firstWhere((t) => t.id == 'smart_document_formatter');
      expect(formatterTool.title, 'Smart Formatter & Tables');
      expect(formatterTool.category, ToolCategory.create);

      final organizerTool = allTools.firstWhere((t) => t.id == 'advanced_page_organizer');
      expect(organizerTool.title, 'Page Organizer');
      expect(organizerTool.category, ToolCategory.managePdf);

      final annotatorTool = allTools.firstWhere((t) => t.id == 'pdf_annotation_signature');
      expect(annotatorTool.title, 'Annotate & Sign PDF');
      expect(annotatorTool.category, ToolCategory.managePdf);
    });

    test('PdfOperationsService inspectPdf and extractTextFromPdf accurately distinguish text vs blank/scanned PDFs', () async {
      final textPdf = createSamplePdf('detect_text.pdf', 2, blank: false);
      final blankPdf = createSamplePdf('detect_blank.pdf', 1, blank: true);

      final textResult = await PdfOperationsService.instance.extractTextFromPdf(pdfPath: textPdf.path);
      expect(textResult.pageCount, 2);
      expect(textResult.isScannedOrEmpty, isFalse);
      expect(textResult.text.contains('Sample Document Content'), isTrue);

      final blankResult = await PdfOperationsService.instance.extractTextFromPdf(pdfPath: blankPdf.path);
      expect(blankResult.pageCount, 1);
      expect(blankResult.isScannedOrEmpty, isTrue);
    });

    test('Multi-page PDF text editing workflow handles coordinate-based replacement and generates valid output', () async {
      final sourcePdf = createSamplePdf('multi_page_edit.pdf', 3);
      final bytes = sourcePdf.readAsBytesSync();
      final doc = sf.PdfDocument(inputBytes: bytes);

      // Perform a simulated text replacement edit on page 2 (index 1)
      final targetPage = doc.pages[1];
      final pageSize = targetPage.size;

      // Draw whiteout rectangle
      targetPage.graphics.drawRectangle(
        brush: sf.PdfSolidBrush(sf.PdfColor(255, 255, 255)),
        bounds: Rect.fromLTWH(50, 50, pageSize.width - 100, 60),
      );

      // Draw replacement text
      final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 14);
      targetPage.graphics.drawString(
        'REPLACED_TEXT_BLOCK_CONFIRMED',
        font,
        brush: sf.PdfSolidBrush(sf.PdfColor(112, 70, 168)),
        bounds: Rect.fromLTWH(50, 50, pageSize.width - 100, 60),
      );

      final editedBytes = await doc.save();
      doc.dispose();

      final editedFile = File('${tempDir.path}/edited_output.pdf');
      editedFile.writeAsBytesSync(editedBytes);

      expect(editedFile.existsSync(), isTrue);
      final reloaded = sf.PdfDocument(inputBytes: editedBytes);
      expect(reloaded.pages.count, 3);

      final extractor = sf.PdfTextExtractor(reloaded);
      final page2Text = extractor.extractText(startPageIndex: 1, endPageIndex: 1);
      expect(page2Text.contains('REPLACED_TEXT_BLOCK_CONFIRMED'), isTrue);
      reloaded.dispose();
    });
  });

  group('Feature 2: Smart Document Formatter & Table Builder Service', () {
    test('Builds formatted document with Title, Headings, Lists, and Tables to valid PDF', () async {
      final sections = [
        FormatterSection(
          id: '1',
          type: DocumentSectionType.title,
          text: 'Quarterly Project Summary',
        ),
        FormatterSection(
          id: '2',
          type: DocumentSectionType.heading1,
          text: '1. Executive Overview',
        ),
        FormatterSection(
          id: '3',
          type: DocumentSectionType.paragraph,
          text: 'This document was compiled using the Smart Document Formatter service.',
        ),
        FormatterSection(
          id: '4',
          type: DocumentSectionType.bulletList,
          listItems: ['High stability', 'Zero regressions', 'Full offline capability'],
        ),
        FormatterSection(
          id: '5',
          type: DocumentSectionType.divider,
        ),
        FormatterSection(
          id: '6',
          type: DocumentSectionType.heading2,
          text: '2. Metrics Table',
        ),
        FormatterSection(
          id: '7',
          type: DocumentSectionType.table,
          tableData: [
            ['Module', 'Status', 'Coverage'],
            ['PDF Editor', 'Passed', '100%'],
            ['Table Builder', 'Passed', '100%'],
            ['Page Organizer', 'Passed', '100%'],
          ],
        ),
      ];

      final result = await SmartDocumentFormatterService.instance.generateFormattedPdf(
        sections: sections,
        options: const SmartFormatterOptions(
          documentTitle: 'Quarterly Project Summary',
          subtitle: 'Internal Technical Report',
          margin: 36,
        ),
        outputDirectory: tempDir,
        customFileName: 'test_formatted_doc.pdf',
      );

      expect(result.file.existsSync(), isTrue);
      expect(result.pageCount, greaterThanOrEqualTo(1));

      final bytes = result.file.readAsBytesSync();
      // Valid PDF begins with %PDF-
      final header = String.fromCharCodes(bytes.take(5));
      expect(header, '%PDF-');

      // Verify the generated PDF can be parsed back with SfPdfDocument
      final loadedDoc = sf.PdfDocument(inputBytes: bytes);
      expect(loadedDoc.pages.count, greaterThanOrEqualTo(1));
      loadedDoc.dispose();
    });

    test('Multi-page pagination correctly wraps large table and multiple sections across pages', () async {
      // Create a 25-row table plus multiple paragraphs to guarantee multi-page layout
      final List<List<String>> largeTableData = [
        ['ID', 'Item Description', 'Department', 'Q1 Target', 'Q2 Target', 'Status']
      ];
      for (int i = 1; i <= 25; i++) {
        largeTableData.add([
          '#$i',
          'Operational Workstream Item $i with detailed documentation',
          'Engineering',
          '${i * 10}%',
          '${i * 15}%',
          i % 2 == 0 ? 'Completed' : 'In Progress',
        ]);
      }

      final sections = [
        FormatterSection(
          id: 'title_1',
          type: DocumentSectionType.title,
          text: 'Annual Multi-Page Enterprise Report',
        ),
        FormatterSection(
          id: 'h1_1',
          type: DocumentSectionType.heading1,
          text: 'Section A: Background and Scope',
        ),
        FormatterSection(
          id: 'p_1',
          type: DocumentSectionType.paragraph,
          text: 'Detailed description explaining the background and scope of the initiative across all engineering departments.',
        ),
        FormatterSection(
          id: 'tbl_1',
          type: DocumentSectionType.table,
          tableData: largeTableData,
        ),
      ];

      final result = await SmartDocumentFormatterService.instance.generateFormattedPdf(
        sections: sections,
        options: const SmartFormatterOptions(
          documentTitle: 'Annual Multi-Page Enterprise Report',
          margin: 40,
        ),
        outputDirectory: tempDir,
        customFileName: 'multipage_report.pdf',
      );

      expect(result.file.existsSync(), isTrue);
      expect(result.pageCount, greaterThanOrEqualTo(2));

      final loadedDoc = sf.PdfDocument(inputBytes: result.file.readAsBytesSync());
      expect(loadedDoc.pages.count, result.pageCount);
      loadedDoc.dispose();
    });
  });

  group('Feature 3: OCR Workspace Service', () {
    test('saveExtractedTextAsDocument writes proper .txt file and preserves line breaks', () async {
      const sampleOcrText = 'First line of scanned document\nSecond line of scanned document\n\nThird paragraph starting here with punctuation.';
      final docModel = await OcrService.instance.saveExtractedTextAsDocument(
        text: sampleOcrText,
        customFileName: 'sample_ocr_export.txt',
        outputDirectory: tempDir,
      );

      expect(docModel.type, 'txt');
      expect(docModel.name.endsWith('.txt'), isTrue);

      final file = File(docModel.path);
      expect(file.existsSync(), isTrue);

      final readContent = file.readAsStringSync();
      expect(readContent, sampleOcrText);
      expect(readContent.contains('\n\n'), isTrue);
    });
  });

  group('Feature 4: Advanced PDF Page Organizer', () {
    test('Reorders, rotates, and deletes pages correctly', () async {
      final samplePdf = createSamplePdf('sample_3pages.pdf', 3);

      // Reorder page 3 to first with 90° rotation, followed by page 1 (no rotation).
      // Page 2 is excluded (deleted).
      final specs = [
        const OrganizedPageSpec(originalPageNumber: 3, rotationAngle: 90),
        const OrganizedPageSpec(originalPageNumber: 1, rotationAngle: 0),
      ];

      final result = await PdfOperationsService.instance.organizePdfPages(
        pdfPath: samplePdf.path,
        pages: specs,
        outputDirectory: tempDir,
        customFileName: 'organized_output.pdf',
      );

      expect(result.pageCount, 2);
      expect(result.file.existsSync(), isTrue);

      final modifiedDoc = sf.PdfDocument(inputBytes: result.file.readAsBytesSync());
      expect(modifiedDoc.pages.count, 2);
      expect(modifiedDoc.pages[0].rotation, sf.PdfPageRotateAngle.rotateAngle90);
      expect(modifiedDoc.pages[1].rotation, sf.PdfPageRotateAngle.rotateAngle0);
      modifiedDoc.dispose();
    });

    test('organizePdfPages rejects empty page list preventing empty output creation', () async {
      final samplePdf = createSamplePdf('empty_organize_guard.pdf', 2);
      expect(
        () => PdfOperationsService.instance.organizePdfPages(
          pdfPath: samplePdf.path,
          pages: [],
          outputDirectory: tempDir,
        ),
        throwsArgumentError,
      );
    });

    test('Multi-angle rotations (90, 180, 270) are correctly preserved in PDF pages', () async {
      final samplePdf = createSamplePdf('sample_rotate_all.pdf', 3);

      final specs = [
        const OrganizedPageSpec(originalPageNumber: 1, rotationAngle: 90),
        const OrganizedPageSpec(originalPageNumber: 2, rotationAngle: 180),
        const OrganizedPageSpec(originalPageNumber: 3, rotationAngle: 270),
      ];

      final result = await PdfOperationsService.instance.organizePdfPages(
        pdfPath: samplePdf.path,
        pages: specs,
        outputDirectory: tempDir,
        customFileName: 'all_rotated.pdf',
      );

      expect(result.pageCount, 3);
      final doc = sf.PdfDocument(inputBytes: result.file.readAsBytesSync());
      expect(doc.pages[0].rotation, sf.PdfPageRotateAngle.rotateAngle90);
      expect(doc.pages[1].rotation, sf.PdfPageRotateAngle.rotateAngle180);
      expect(doc.pages[2].rotation, sf.PdfPageRotateAngle.rotateAngle270);
      doc.dispose();
    });
  });

  group('Feature 5: PDF Annotation & Signature Embedding', () {
    test('Embeds highlights, text annotations, freehand paths, and bitmap signature into PDF', () async {
      final samplePdf = createSamplePdf('annot_source.pdf', 2);
      final bytes = samplePdf.readAsBytesSync();
      final doc = sf.PdfDocument(inputBytes: bytes);

      final page = doc.pages[0];
      final pageSize = page.size;

      // 1. Highlight
      page.graphics.drawRectangle(
        brush: sf.PdfSolidBrush(sf.PdfColor(255, 235, 59, 90)),
        bounds: Rect.fromLTWH(0.1 * pageSize.width, 0.1 * pageSize.height, 0.5 * pageSize.width, 0.05 * pageSize.height),
      );

      // 2. Text note
      page.graphics.drawRectangle(
        brush: sf.PdfSolidBrush(sf.PdfColor(255, 255, 255)),
        pen: sf.PdfPen(sf.PdfColor(112, 70, 168), width: 1),
        bounds: Rect.fromLTWH(0.1 * pageSize.width, 0.2 * pageSize.height, 200, 40),
      );
      page.graphics.drawString(
        'Verified and Approved',
        sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 10),
        brush: sf.PdfSolidBrush(sf.PdfColor(45, 36, 53)),
        bounds: Rect.fromLTWH(0.1 * pageSize.width + 4, 0.2 * pageSize.height + 4, 192, 32),
      );

      // 3. Freehand stroke
      final pen = sf.PdfPen(sf.PdfColor(112, 70, 168), width: 2.5);
      page.graphics.drawLine(
        pen,
        Offset(0.1 * pageSize.width, 0.3 * pageSize.height),
        Offset(0.4 * pageSize.width, 0.3 * pageSize.height),
      );

      // 4. Signature bitmap (minimal 1x1 transparent/black PNG)
      final pngHeader = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82
      ]);
      final bitmap = sf.PdfBitmap(pngHeader);
      page.graphics.drawImage(
        bitmap,
        Rect.fromLTWH(0.1 * pageSize.width, 0.4 * pageSize.height, 100, 40),
      );

      final exportedBytes = await doc.save();
      doc.dispose();

      final exportedFile = File('${tempDir.path}/annotated_test_doc.pdf');
      exportedFile.writeAsBytesSync(exportedBytes);

      expect(exportedFile.existsSync(), isTrue);
      final reloaded = sf.PdfDocument(inputBytes: exportedBytes);
      expect(reloaded.pages.count, 2);

      // Verify text annotation is extractable
      final extractor = sf.PdfTextExtractor(reloaded);
      final page1Text = extractor.extractText(startPageIndex: 0, endPageIndex: 0);
      expect(page1Text.contains('Verified and Approved'), isTrue);
      reloaded.dispose();
    });
  });

  group('Feature 6: Document Converter Service (PDF <-> Word DOCX)', () {
    test('Assesses PDF structure accurately (text vs scanned)', () async {
      final textPdf = createSamplePdf('text_doc.pdf', 2);
      final assessment = await DocumentConverterService.instance.assessPdf(textPdf.path);

      expect(assessment.isValid, isTrue);
      expect(assessment.isScannedOrEmpty, isFalse);
      expect(assessment.estimatedParagraphs, greaterThanOrEqualTo(1));
    });

    test('Converts PDF with text to genuine OpenXML .docx with valid ZIP structure and styles', () async {
      final textPdf = createSamplePdf('to_word.pdf', 1);

      final docxFile = await DocumentConverterService.instance.convertPdfToDocx(
        pdfPath: textPdf.path,
        outputDirectory: tempDir,
        customFileName: 'output_document.docx',
      );

      expect(docxFile.existsSync(), isTrue);
      final bytes = docxFile.readAsBytesSync();

      // Verify valid PK zip archive structure
      final archive = ZipDecoder().decodeBytes(bytes);
      final filenames = archive.files.map((f) => f.name).toSet();

      expect(filenames.contains('[Content_Types].xml'), isTrue);
      expect(filenames.contains('_rels/.rels'), isTrue);
      expect(filenames.contains('word/document.xml'), isTrue);
      expect(filenames.contains('word/styles.xml'), isTrue);

      // Verify document.xml contains the text from our sample PDF
      final docXmlFile = archive.findFile('word/document.xml');
      expect(docXmlFile, isNotNull);
      final docXmlContent = String.fromCharCodes(docXmlFile!.content as List<int>);
      expect(docXmlContent.contains('Sample Document Content'), isTrue);
    });

    test('Converts genuine .docx back to PDF with formatting', () async {
      final textPdf = createSamplePdf('orig_pdf.pdf', 1);
      final docxFile = await DocumentConverterService.instance.convertPdfToDocx(
        pdfPath: textPdf.path,
        outputDirectory: tempDir,
        customFileName: 'roundtrip.docx',
      );

      final reconvertedFile = await DocumentConverterService.instance.convertDocxToPdf(
        docxPath: docxFile.path,
        outputDirectory: tempDir,
        customFileName: 'reconverted.pdf',
      );

      expect(reconvertedFile.existsSync(), isTrue);
      final pdfBytes = reconvertedFile.readAsBytesSync();
      expect(String.fromCharCodes(pdfBytes.take(5)), '%PDF-');

      final loadedDoc = sf.PdfDocument(inputBytes: pdfBytes);
      expect(loadedDoc.pages.count, greaterThanOrEqualTo(1));
      loadedDoc.dispose();
    });

    test('Converts DOCX with OpenXML table elements into formatted PDF', () async {
      // Build a minimal DOCX archive containing a table
      final archive = Archive();
      archive.addFile(ArchiveFile('[Content_Types].xml', 0, Uint8List.fromList(
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>'''.codeUnits,
      )));

      archive.addFile(ArchiveFile('word/document.xml', 0, Uint8List.fromList(
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>Table Demonstration Header</w:t></w:r></w:p>
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Column A</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Column B</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Val 1</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Val 2</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
  </w:body>
</w:document>'''.codeUnits,
      )));

      final docxBytes = ZipEncoder().encode(archive);
      final sampleDocxFile = File('${tempDir.path}/test_table.docx');
      sampleDocxFile.writeAsBytesSync(docxBytes);

      final pdfFile = await DocumentConverterService.instance.convertDocxToPdf(
        docxPath: sampleDocxFile.path,
        outputDirectory: tempDir,
        customFileName: 'from_table_docx.pdf',
      );

      expect(pdfFile.existsSync(), isTrue);
      final pdfDoc = sf.PdfDocument(inputBytes: pdfFile.readAsBytesSync());
      expect(pdfDoc.pages.count, greaterThanOrEqualTo(1));

      final text = sf.PdfTextExtractor(pdfDoc).extractText();
      expect(text.contains('Table Demonstration Header'), isTrue);
      expect(text.contains('Column A'), isTrue);
      expect(text.contains('Val 1'), isTrue);
      pdfDoc.dispose();
    });

    test('DocumentSaveService sanitizes unique filenames correctly across extensions', () {
      final saveService = DocumentSaveService.instance;

      // Create dummy file
      final dummyDocx = File('${tempDir.path}/my_doc.docx');
      dummyDocx.writeAsStringSync('dummy');

      final unique1 = saveService.generateUniqueFileName(directory: tempDir, baseName: 'my_doc.docx');
      expect(unique1, 'my_doc (1).docx');

      final dummyDocx1 = File('${tempDir.path}/my_doc (1).docx');
      dummyDocx1.writeAsStringSync('dummy 1');

      final unique2 = saveService.generateUniqueFileName(directory: tempDir, baseName: 'my_doc.docx');
      expect(unique2, 'my_doc (2).docx');
    });
  });
}
