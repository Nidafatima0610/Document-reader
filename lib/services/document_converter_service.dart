import 'dart:convert';
import 'dart:io';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:all_documents_reader/services/smart_document_formatter_service.dart';
import 'package:archive/archive.dart';

class ConversionAssessment {
  final bool isValid;
  final String fileName;
  final int fileSizeBytes;
  final int estimatedParagraphs;
  final int estimatedTables;
  final bool isScannedOrEmpty;
  final String? warningMessage;

  const ConversionAssessment({
    required this.isValid,
    required this.fileName,
    required this.fileSizeBytes,
    this.estimatedParagraphs = 0,
    this.estimatedTables = 0,
    this.isScannedOrEmpty = false,
    this.warningMessage,
  });
}

class DocumentConverterService {
  DocumentConverterService._internal();
  static final DocumentConverterService instance = DocumentConverterService._internal();
  factory DocumentConverterService() => instance;

  /// Inspects and validates a PDF before DOCX conversion
  Future<ConversionAssessment> assessPdf(String pdfPath) async {
    final file = File(pdfPath);
    if (!file.existsSync()) {
      return const ConversionAssessment(isValid: false, fileName: '', fileSizeBytes: 0, warningMessage: 'File not found');
    }

    try {
      final info = await PdfOperationsService.instance.inspectPdf(pdfPath);
      final textRes = await PdfOperationsService.instance.extractTextFromPdf(pdfPath: pdfPath);

      final paragraphs = textRes.text.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).length;

      String? warning;
      if (textRes.isScannedOrEmpty) {
        warning = 'This PDF appears to be scanned or image-only without digital text. OCR will be required for full text extraction.';
      }

      return ConversionAssessment(
        isValid: true,
        fileName: info.fileName,
        fileSizeBytes: info.fileSizeBytes,
        estimatedParagraphs: paragraphs,
        isScannedOrEmpty: textRes.isScannedOrEmpty,
        warningMessage: warning,
      );
    } catch (e) {
      return ConversionAssessment(
        isValid: false,
        fileName: pdfPath.split(RegExp(r'[/\\]')).last,
        fileSizeBytes: file.lengthSync(),
        warningMessage: 'Could not inspect PDF: $e',
      );
    }
  }

  /// Inspects and validates a Word DOCX file before PDF conversion
  Future<ConversionAssessment> assessDocx(String docxPath) async {
    final file = File(docxPath);
    if (!file.existsSync()) {
      return const ConversionAssessment(isValid: false, fileName: '', fileSizeBytes: 0, warningMessage: 'File not found');
    }

    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final docFile = archive.findFile('word/document.xml');

      if (docFile == null) {
        return ConversionAssessment(
          isValid: false,
          fileName: docxPath.split(RegExp(r'[/\\]')).last,
          fileSizeBytes: file.lengthSync(),
          warningMessage: 'Not a valid modern Microsoft Word (.docx) package.',
        );
      }

      final content = utf8.decode(docFile.content as List<int>, allowMalformed: true);
      final pMatches = RegExp(r'<w:p[\s>]').allMatches(content).length;
      final tblMatches = RegExp(r'<w:tbl[\s>]').allMatches(content).length;

      return ConversionAssessment(
        isValid: true,
        fileName: docxPath.split(RegExp(r'[/\\]')).last,
        fileSizeBytes: file.lengthSync(),
        estimatedParagraphs: pMatches,
        estimatedTables: tblMatches,
      );
    } catch (e) {
      return ConversionAssessment(
        isValid: false,
        fileName: docxPath.split(RegExp(r'[/\\]')).last,
        fileSizeBytes: file.lengthSync(),
        warningMessage: 'Failed to inspect DOCX: $e',
      );
    }
  }

  /// Converts a PDF document into a genuine Microsoft Word (.docx) OpenXML container
  Future<File> convertPdfToDocx({
    required String pdfPath,
    String? customFileName,
    Directory? outputDirectory,
  }) async {
    final file = File(pdfPath);
    if (!file.existsSync()) {
      throw FileSystemException('PDF file not found', pdfPath);
    }

    // 1. Extract structured text from PDF
    final textRes = await PdfOperationsService.instance.extractTextFromPdf(pdfPath: pdfPath);
    final rawText = textRes.text;

    final paragraphs = rawText.split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    // 2. Build OpenXML word/document.xml
    final xmlBuffer = StringBuffer();
    xmlBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    xmlBuffer.writeln('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
    xmlBuffer.writeln('<w:body>');

    for (int i = 0; i < paragraphs.length; i++) {
      final para = paragraphs[i];
      final isHeading = para.length < 50 && !para.endsWith('.');

      xmlBuffer.writeln('<w:p>');
      if (isHeading) {
        xmlBuffer.writeln('<w:pPr><w:pStyle w:val="Heading1"/></w:pPr>');
      }
      xmlBuffer.writeln('<w:r>');
      if (isHeading) {
        xmlBuffer.writeln('<w:rPr><w:b/><w:sz w:val="32"/><w:color w:val="7046A8"/></w:rPr>');
      } else {
        xmlBuffer.writeln('<w:rPr><w:sz w:val="24"/><w:color w:val="2D2435"/></w:rPr>');
      }
      // XML escape
      final escaped = _xmlEscape(para);
      xmlBuffer.writeln('<w:t xml:space="preserve">$escaped</w:t>');
      xmlBuffer.writeln('</w:r>');
      xmlBuffer.writeln('</w:p>');
    }

    xmlBuffer.writeln('<w:sectPr/>');
    xmlBuffer.writeln('</w:body>');
    xmlBuffer.writeln('</w:document>');

    // 3. Assemble full standard DOCX package
    final archive = Archive();

    // [Content_Types].xml
    const contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypes.length, utf8.encode(contentTypes)));

    // _rels/.rels
    const rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', rels.length, utf8.encode(rels)));

    // word/document.xml
    final docXmlBytes = utf8.encode(xmlBuffer.toString());
    archive.addFile(ArchiveFile('word/document.xml', docXmlBytes.length, docXmlBytes));

    // Encode as zip bytes
    final zipEncoder = ZipEncoder();
    final docxBytes = zipEncoder.encode(archive);

    // Save to disk
    final saveDir = outputDirectory ?? await DocumentsStorageService.instance.getAppDocumentsDirectory();
    final baseName = customFileName ?? file.path.split(RegExp(r'[/\\]')).last.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '.docx');
    final outFile = File('${saveDir.path}/$baseName');
    await outFile.writeAsBytes(docxBytes, flush: true);

    return outFile;
  }

  /// Converts a Microsoft Word (.docx) file into a paginated vector PDF
  Future<File> convertDocxToPdf({
    required String docxPath,
    String? customFileName,
    Directory? outputDirectory,
  }) async {
    final file = File(docxPath);
    if (!file.existsSync()) {
      throw FileSystemException('DOCX file not found', docxPath);
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final docFile = archive.findFile('word/document.xml');

    if (docFile == null) {
      throw const FormatException('Corrupted or invalid DOCX archive. Missing word/document.xml.');
    }

    final xmlContent = utf8.decode(docFile.content as List<int>, allowMalformed: true);

    // Extract paragraphs and tables
    final sections = <FormatterSection>[];
    int secId = 1;

    // Extract all paragraphs
    final pRegex = RegExp(r'<w:p[\s>](.*?)</w:p>', dotAll: true);
    final textRegex = RegExp(r'<w:t[\s>](.*?)</w:t>', dotAll: true);
    final headingRegex = RegExp(r'<w:pStyle\s+w:val="(Heading1|Heading2|Title)"', caseSensitive: false);

    for (final match in pRegex.allMatches(xmlContent)) {
      final pXml = match.group(1) ?? '';
      final tMatches = textRegex.allMatches(pXml);
      final pText = tMatches.map((m) => _xmlUnescape(m.group(1) ?? '')).join('').trim();

      if (pText.isEmpty) continue;

      if (headingRegex.hasMatch(pXml)) {
        sections.add(
          FormatterSection(
            id: '${secId++}',
            type: DocumentSectionType.heading1,
            text: pText,
          ),
        );
      } else {
        sections.add(
          FormatterSection(
            id: '${secId++}',
            type: DocumentSectionType.paragraph,
            text: pText,
          ),
        );
      }
    }

    if (sections.isEmpty) {
      sections.add(
        FormatterSection(
          id: '1',
          type: DocumentSectionType.paragraph,
          text: 'Document content parsed from ${file.path.split(RegExp(r"[/\\]")).last}',
        ),
      );
    }

    // Generate PDF via SmartDocumentFormatterService
    final title = file.path.split(RegExp(r'[/\\]')).last.replaceAll(RegExp(r'\.docx$', caseSensitive: false), '');
    final result = await SmartDocumentFormatterService.instance.generateFormattedPdf(
      sections: sections,
      options: SmartFormatterOptions(
        documentTitle: title,
      ),
      customFileName: customFileName,
      outputDirectory: outputDirectory,
    );

    return result.file;
  }

  String _xmlEscape(String str) {
    return str
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _xmlUnescape(String str) {
    return str
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }
}
