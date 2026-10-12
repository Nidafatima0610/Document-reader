import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:all_documents_reader/models/tool_item_model.dart';
import 'package:all_documents_reader/services/smart_document_formatter_service.dart';
import 'package:all_documents_reader/services/document_converter_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:all_documents_reader/services/tools_registry_service.dart';
import 'package:archive/archive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('six_features_test_');
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // Helper to create a simple multi-page PDF in tempDir
  File createSamplePdf(String filename, int pageCount) {
    final document = sf.PdfDocument();
    for (int i = 0; i < pageCount; i++) {
      final page = document.pages.add();
      final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 16);
      page.graphics.drawString(
        'Page ${i + 1} of $pageCount\nSample Document Content for Testing',
        font,
        bounds: const Rect.fromLTWH(50, 50, 400, 100),
      );
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
  });

  group('Feature 6: Document Converter Service (PDF <-> Word DOCX)', () {
    test('Assesses PDF structure accurately (text vs scanned)', () async {
      final textPdf = createSamplePdf('text_doc.pdf', 2);
      final assessment = await DocumentConverterService.instance.assessPdf(textPdf.path);

      expect(assessment.isValid, isTrue);
      expect(assessment.isScannedOrEmpty, isFalse);
      expect(assessment.estimatedParagraphs, greaterThanOrEqualTo(1));
    });

    test('Converts PDF with text to genuine OpenXML .docx with valid ZIP structure', () async {
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
  });
}
