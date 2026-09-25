import 'package:all_documents_reader/core/config/app_config.dart';
import 'package:all_documents_reader/models/tool_item_model.dart';
import 'package:all_documents_reader/views/ai_document_assistant_view.dart';
import 'package:all_documents_reader/views/compress_pdf_view.dart';
import 'package:all_documents_reader/views/image_to_text_view.dart';
import 'package:all_documents_reader/views/images_to_pdf_view.dart';
import 'package:all_documents_reader/views/merge_pdf_view.dart';
import 'package:all_documents_reader/views/ocr_workspace_view.dart';
import 'package:all_documents_reader/views/pdf_to_image_view.dart';
import 'package:all_documents_reader/views/pdf_to_text_view.dart';
import 'package:all_documents_reader/views/reorder_pdf_view.dart';
import 'package:all_documents_reader/views/rotate_pdf_view.dart';
import 'package:all_documents_reader/views/smart_scanner_view.dart';
import 'package:all_documents_reader/views/split_pdf_view.dart';
import 'package:all_documents_reader/views/text_to_pdf_view.dart';
import 'package:all_documents_reader/views/word_converter_view.dart';
import 'package:flutter/material.dart';

/// Central registry managing all document utility tools
class ToolsRegistryService {
  ToolsRegistryService._internal();
  static final ToolsRegistryService instance = ToolsRegistryService._internal();
  factory ToolsRegistryService() => instance;

  final List<ToolItemModel> _tools = [
    // ----------------------------------------------------
    // CREATE CATEGORY
    // ----------------------------------------------------
    ToolItemModel(
      id: 'smart_scanner',
      title: 'Smart Scanner',
      description: 'Capture documents, crop boundaries, enhance filters & OCR',
      category: ToolCategory.create,
      icon: Icons.document_scanner_rounded,
      accentColor: const Color(0xFF7C3AED),
      status: ToolStatus.available,
      supportedInputFormats: const ['Camera', 'JPG', 'PNG'],
      outputFormat: 'PDF / TXT',
      routeBuilder: (context) => const SmartScannerView(),
      features: const [
        'Multi-page physical document camera capture and gallery import',
        'Interactive manual boundary crop with A4 presets',
        'Real document enhancement filters (Original, Grayscale, B&W, Enhanced)',
        'Compile into searchable/sharable PDF and extract text with on-device OCR',
      ],
    ),
    ToolItemModel(
      id: 'images_to_pdf',
      title: 'Images to PDF',
      description: 'Combine multiple photos or camera scans into a multi-page PDF',
      category: ToolCategory.create,
      icon: Icons.photo_library_outlined,
      accentColor: const Color(0xFF6C4AB6),
      status: ToolStatus.available,
      supportedInputFormats: const ['JPG', 'JPEG', 'PNG', 'WEBP', 'BMP'],
      outputFormat: 'PDF',
      routeBuilder: (context) => const ImagesToPdfView(),
      features: const [
        'Batch select multiple images from gallery or camera',
        'Reorder images before generating the document',
        'Automatic page orientation and margin adjustment',
        'Save directly to saved Documents list',
      ],
    ),
    ToolItemModel(
      id: 'text_to_pdf',
      title: 'Text to PDF',
      description: 'Create formatted PDF documents directly from written notes',
      category: ToolCategory.create,
      icon: Icons.post_add_rounded,
      accentColor: const Color(0xFF8E44AD),
      status: ToolStatus.available,
      supportedInputFormats: const ['TXT', 'Plain Text'],
      outputFormat: 'PDF',
      routeBuilder: (context) => const TextToPdfView(),
      features: const [
        'Rich multi-paragraph text typing and pasting area',
        'Automatic multi-page pagination and layout flow',
        'Customizable font sizes and title header',
        'Export clean, ready-to-share PDF documents',
      ],
    ),

    // ----------------------------------------------------
    // CONVERT CATEGORY
    // ----------------------------------------------------
    ToolItemModel(
      id: 'image_to_pdf',
      title: 'Image to PDF',
      description: 'Convert a single image or graphic file into a clean PDF',
      category: ToolCategory.convert,
      icon: Icons.image_outlined,
      accentColor: const Color(0xFF2980B9),
      status: ToolStatus.available,
      supportedInputFormats: const ['JPG', 'PNG', 'WEBP', 'BMP'],
      outputFormat: 'PDF',
      routeBuilder: (context) => const ImagesToPdfView(),
      features: const [
        'Preserve original aspect ratio and resolution',
        'Auto-fit to standard page sizing without distortion',
        'Lossless quality conversion',
        'Quick preview before saving',
      ],
    ),
    ToolItemModel(
      id: 'pdf_to_image',
      title: 'PDF to Image',
      description: 'Extract PDF pages as high-resolution PNG images',
      category: ToolCategory.convert,
      icon: Icons.photo_size_select_actual_outlined,
      accentColor: const Color(0xFF00897B),
      status: ToolStatus.available,
      supportedInputFormats: const ['PDF'],
      outputFormat: 'PNG',
      routeBuilder: (context) => const PdfToImageView(),
      features: const [
        'Render pages at up to 300 DPI high clarity',
        'Extract specific single pages or entire document',
        'Export as individual image files into dedicated directory',
        'Add generated images directly to Documents reader',
      ],
    ),
    ToolItemModel(
      id: 'pdf_to_text',
      title: 'PDF to Text',
      description: 'Extract selectable text and snippets from PDF documents',
      category: ToolCategory.convert,
      icon: Icons.text_snippet_outlined,
      accentColor: const Color(0xFFD35400),
      status: ToolStatus.available,
      supportedInputFormats: const ['PDF'],
      outputFormat: 'TXT / Clipboard',
      routeBuilder: (context) => const PdfToTextView(),
      features: const [
        'Extract digital text paragraphs cleanly',
        'Copy directly to clipboard with one tap',
        'Save extracted content as a .txt document',
        'Detects scanned documents without text layers',
      ],
    ),
    ToolItemModel(
      id: 'image_to_text',
      title: 'Image to Text',
      description: 'Extract text from photos, scans, and documents using OCR',
      category: ToolCategory.convert,
      icon: Icons.document_scanner_outlined,
      accentColor: const Color(0xFFC2185B),
      status: ToolStatus.available,
      supportedInputFormats: const ['JPG', 'JPEG', 'PNG'],
      outputFormat: 'TXT / Clipboard',
      routeBuilder: (context) => const ImageToTextView(),
      features: const [
        'On-device Optical Character Recognition (OCR)',
        'Accurate multi-lingual text detection',
        'Direct text editing before saving or copying',
        'Save recognized text as document',
      ],
    ),
    ToolItemModel(
      id: 'ocr_workspace',
      title: 'OCR Workspace',
      description: 'Multi-page text extraction from images, scans, and PDFs with editing and AI',
      category: ToolCategory.convert,
      icon: Icons.document_scanner_rounded,
      accentColor: const Color(0xFFC2185B),
      status: ToolStatus.available,
      supportedInputFormats: const ['Camera', 'JPG', 'PNG', 'PDF'],
      outputFormat: 'TXT / AI',
      routeBuilder: (context) => const OcrWorkspaceView(),
      features: const [
        'Batch multi-page OCR extraction',
        'Direct PDF text extraction & scanned page OCR',
        'Interactive text editor with copy, clear, and word count',
        'One-tap bridge to AI Document Assistant',
      ],
    ),
    ToolItemModel(
      id: 'ai_document_assistant',
      title: 'AI Document Assistant',
      description: 'Summarize, extract entities, generate study notes, and ask questions',
      category: ToolCategory.convert,
      icon: Icons.auto_awesome_rounded,
      accentColor: const Color(0xFF7046A8),
      status: ToolStatus.available,
      supportedInputFormats: const ['PDF', 'TXT', 'DOC', 'Text'],
      outputFormat: 'TXT / Insights',
      routeBuilder: (context) => const AiDocumentAssistantView(),
      features: const [
        'On-device Smart NLP Engine (100% private, offline, no API key needed)',
        'Executive summaries, key points, and plain-language explanations',
        'Entity extraction for dates, amounts, deadlines, and organizations',
        'Contextual document Q&A and ATS-style CV/Resume critique',
      ],
    ),
    ToolItemModel(
      id: 'word_to_pdf',
      title: 'Word to PDF',
      description: 'Convert DOC and DOCX Word documents into standard PDF files',
      category: ToolCategory.convert,
      icon: Icons.description_outlined,
      accentColor: const Color(0xFF1565C0),
      status: ToolStatus.available,
      supportedInputFormats: const ['DOC', 'DOCX'],
      outputFormat: 'PDF',
      routeBuilder: (context) => const WordConverterView(
        mode: WordConversionMode.wordToPdf,
      ),
      features: const [
        'Full technical feasibility analysis',
        'Guidelines on desktop/cloud Office rendering engines',
        'Recommended offline alternatives',
        'Zero fake conversion buttons',
      ],
    ),
    ToolItemModel(
      id: 'pdf_to_word',
      title: 'PDF to Word',
      description: 'Convert PDF files back into editable Word documents (.docx)',
      category: ToolCategory.convert,
      icon: Icons.article_outlined,
      accentColor: const Color(0xFF1976D2),
      status: ToolStatus.available,
      supportedInputFormats: const ['PDF'],
      outputFormat: 'DOCX',
      routeBuilder: (context) => const WordConverterView(
        mode: WordConversionMode.pdfToWord,
      ),
      features: const [
        'Full technical feasibility analysis',
        'Information on semantic layout reconstruction',
        'Recommended working alternatives',
        'Zero fake conversion buttons',
      ],
    ),

    // ----------------------------------------------------
    // MANAGE PDF CATEGORY
    // ----------------------------------------------------
    ToolItemModel(
      id: 'merge_pdf',
      title: 'Merge PDF',
      description: 'Combine two or more PDF files into a single unified file',
      category: ToolCategory.managePdf,
      icon: Icons.call_merge_rounded,
      accentColor: const Color(0xFF7B1FA2),
      status: ToolStatus.available,
      supportedInputFormats: const ['PDF'],
      outputFormat: 'PDF',
      routeBuilder: (context) => const MergePdfView(),
      features: const [
        'Select multiple PDF files from storage',
        'Visual drag-and-drop file reordering',
        'Preserve native page dimensions and clarity',
        'Instant preview and single-tap save to Documents',
      ],
    ),
    ToolItemModel(
      id: 'split_pdf',
      title: 'Split PDF',
      description: 'Extract specific pages or page ranges into individual PDFs',
      category: ToolCategory.managePdf,
      icon: Icons.call_split_rounded,
      accentColor: const Color(0xFF0097A7),
      status: ToolStatus.available,
      supportedInputFormats: const ['PDF'],
      outputFormat: 'PDF',
      routeBuilder: (context) => const SplitPdfView(),
      features: const [
        'Interactive page chip selection',
        'Specify custom ranges (e.g. 1-3, 5)',
        'Extract selected pages into new PDF',
        'Organized naming and Documents integration',
      ],
    ),
    ToolItemModel(
      id: 'compress_pdf',
      title: 'Compress PDF',
      description: 'Reduce file size of large PDFs while preserving text sharpness',
      category: ToolCategory.managePdf,
      icon: Icons.compress_rounded,
      accentColor: const Color(0xFF2E7D32),
      status: ToolStatus.available,
      supportedInputFormats: const ['PDF'],
      outputFormat: 'PDF',
      routeBuilder: (context) => const CompressPdfView(),
      features: const [
        'Flate/Deflate stream re-encoding',
        'Eliminates unreferenced objects and orphaned tables',
        'Honest before vs after byte size metrics',
        'Preserves text sharpness without lossy distortion',
      ],
    ),
    ToolItemModel(
      id: 'rotate_pdf',
      title: 'Rotate PDF',
      description: 'Permanently adjust orientation of PDF pages (90°, 180°, 270°)',
      category: ToolCategory.managePdf,
      icon: Icons.rotate_right_rounded,
      accentColor: const Color(0xFFE65100),
      status: ToolStatus.available,
      supportedInputFormats: const ['PDF'],
      outputFormat: 'PDF',
      routeBuilder: (context) => const RotatePdfView(),
      features: const [
        'Rotate all pages or selectively picked pages',
        '90° clockwise, 180°, and 270° orientation adjustments',
        'Permanent orientation metadata updating',
        'Instant save and open',
      ],
    ),
    ToolItemModel(
      id: 'reorder_pdf',
      title: 'Reorder PDF Pages',
      description: 'Drag and re-arrange page order, delete or duplicate pages',
      category: ToolCategory.managePdf,
      icon: Icons.reorder_rounded,
      accentColor: const Color(0xFF5D4037),
      status: ToolStatus.available,
      supportedInputFormats: const ['PDF'],
      outputFormat: 'PDF',
      routeBuilder: (context) => const ReorderPdfView(),
      features: const [
        'Interactive drag-and-drop page reordering',
        'One-tap delete unwanted pages',
        'Save reordered result to a new PDF file',
        'Integrated with Documents system',
      ],
    ),
  ];

  List<ToolItemModel> get _activeTools {
    if (AppConfig.isAiFeatureEnabled) {
      return _tools;
    }
    return _tools.where((t) => t.id != 'ai_document_assistant').toList();
  }

  /// Retrieve all registered tool definitions regardless of UI enablement
  List<ToolItemModel> get allRegisteredTools => List.unmodifiable(_tools);

  /// Retrieve all registered tools available in the UI
  List<ToolItemModel> getAllTools() => List.unmodifiable(_activeTools);

  /// Retrieve tools filtered by specific category
  List<ToolItemModel> getToolsByCategory(ToolCategory category) {
    return _activeTools.where((tool) => tool.category == category).toList();
  }

  /// Search tools across title, description, and keywords
  List<ToolItemModel> searchTools(String query, {ToolCategory? category}) {
    final cleanQuery = query.trim().toLowerCase();
    return _activeTools.where((tool) {
      if (category != null && tool.category != category) {
        return false;
      }
      if (cleanQuery.isEmpty) {
        return true;
      }
      final inTitle = tool.title.toLowerCase().contains(cleanQuery);
      final inDescription = tool.description.toLowerCase().contains(cleanQuery);
      final inFormats = tool.supportedInputFormats.any(
        (fmt) => fmt.toLowerCase().contains(cleanQuery),
      );
      final inOutput = tool.outputFormat.toLowerCase().contains(cleanQuery);
      return inTitle || inDescription || inFormats || inOutput;
    }).toList();
  }
}
