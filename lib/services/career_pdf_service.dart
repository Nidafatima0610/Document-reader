import 'dart:io';
import 'package:all_documents_reader/models/career_models.dart';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Offset, Rect;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Professional PDF Generation Service for Career Documents (CV, Cover Letter, Reference Letter).
/// Uses Syncfusion Flutter PDF to generate multi-page, publication-grade documents
/// and integrates directly into DocumentsStorageService.
class CareerPdfService {
  CareerPdfService._internal();
  static final CareerPdfService instance = CareerPdfService._internal();
  factory CareerPdfService() => instance;

  // Design system colors
  static final PdfColor primaryPurple = PdfColor(112, 70, 168);
  static final PdfColor primaryDark = PdfColor(45, 36, 53);
  static final PdfColor secondarySlate = PdfColor(90, 80, 105);
  static final PdfColor textDark = PdfColor(30, 30, 30);
  static final PdfColor textMuted = PdfColor(105, 100, 115);
  static final PdfColor dividerColor = PdfColor(220, 214, 230);
  static final PdfColor lightBg = PdfColor(246, 243, 250);

  // Fonts
  PdfFont get _fontName =>
      PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
  PdfFont get _fontTitle =>
      PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
  PdfFont get _fontSectionHeader =>
      PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
  PdfFont get _fontSubHeader =>
      PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
  PdfFont get _fontBody => PdfStandardFont(PdfFontFamily.helvetica, 9.5);
  PdfFont get _fontBodyBold =>
      PdfStandardFont(PdfFontFamily.helvetica, 9.5, style: PdfFontStyle.bold);
  PdfFont get _fontMeta =>
      PdfStandardFont(PdfFontFamily.helvetica, 8.5, style: PdfFontStyle.italic);
  PdfFont get _fontContact =>
      PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.regular);

  // ===========================================================================
  // 1. CV / RESUME PDF GENERATION
  // ===========================================================================

  Future<File> generateResumePdf(
    ResumeData data, {
    String? customFileName,
    String? customOutputDir,
  }) async {
    final doc = PdfDocument();
    doc.pageSettings.size = PdfPageSize.a4;
    doc.pageSettings.margins.all = 36; // 0.5 inch margin

    PdfPage page = doc.pages.add();
    double currentY = 0;
    final pageWidth = page.getClientSize().width;
    final pageHeight = page.getClientSize().height;

    void checkNewPage(double neededHeight) {
      if (currentY + neededHeight > pageHeight - 20) {
        page = doc.pages.add();
        currentY = 0;
      }
    }

    // 1. Header Banner: Full Name & Professional Title
    final nameStr = data.fullName.trim().isEmpty ? 'Your Name' : data.fullName.trim();
    page.graphics.drawString(
      nameStr,
      _fontName,
      brush: PdfSolidBrush(primaryPurple),
      bounds: Rect.fromLTWH(0, currentY, pageWidth, 26),
    );
    currentY += 26;

    if (data.professionalTitle.trim().isNotEmpty) {
      page.graphics.drawString(
        data.professionalTitle.trim(),
        _fontTitle,
        brush: PdfSolidBrush(primaryDark),
        bounds: Rect.fromLTWH(0, currentY, pageWidth, 18),
      );
      currentY += 18;
    }

    // 2. Contact details line
    final contactItems = <String>[];
    if (data.phone.trim().isNotEmpty) contactItems.add(data.phone.trim());
    if (data.email.trim().isNotEmpty) contactItems.add(data.email.trim());
    if (data.location.trim().isNotEmpty) contactItems.add(data.location.trim());
    if (data.linkedIn.trim().isNotEmpty) contactItems.add(data.linkedIn.trim());
    if (data.website.trim().isNotEmpty) contactItems.add(data.website.trim());

    if (contactItems.isNotEmpty) {
      final contactLine = contactItems.join('  •  ');
      page.graphics.drawString(
        contactLine,
        _fontContact,
        brush: PdfSolidBrush(textMuted),
        bounds: Rect.fromLTWH(0, currentY, pageWidth, 16),
      );
      currentY += 18;
    }

    // Header divider line
    page.graphics.drawLine(
      PdfPen(primaryPurple, width: 2),
      Offset(0, currentY),
      Offset(pageWidth, currentY),
    );
    currentY += 14;

    // Helper for drawing Section Header
    void drawSectionHeader(String title) {
      checkNewPage(28);
      // Colored accent pill
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(primaryPurple),
        bounds: Rect.fromLTWH(0, currentY + 1, 4, 13),
      );
      page.graphics.drawString(
        '  $title',
        _fontSectionHeader,
        brush: PdfSolidBrush(primaryDark),
        bounds: Rect.fromLTWH(4, currentY, pageWidth - 10, 16),
      );
      currentY += 17;
      page.graphics.drawLine(
        PdfPen(dividerColor, width: 0.8),
        Offset(0, currentY),
        Offset(pageWidth, currentY),
      );
      currentY += 8;
    }

    // 3. Professional Summary
    if (data.summary.trim().isNotEmpty) {
      drawSectionHeader('PROFESSIONAL SUMMARY');
      final summaryElement = PdfTextElement(
        text: data.summary.trim(),
        font: _fontBody,
        brush: PdfSolidBrush(textDark),
        format: PdfStringFormat(lineSpacing: 3),
      );
      final layout = summaryElement.draw(
        page: page,
        bounds: Rect.fromLTWH(0, currentY, pageWidth, pageHeight - currentY),
      );
      if (layout != null) {
        page = layout.page;
        currentY = layout.bounds.bottom + 12;
      }
    }

    // 4. Work Experience
    if (data.experiences.isNotEmpty) {
      drawSectionHeader('WORK EXPERIENCE');
      for (final exp in data.experiences) {
        checkNewPage(45);
        final titleCompany = exp.company.isNotEmpty
            ? '${exp.jobTitle} - ${exp.company}'
            : exp.jobTitle;

        final dateStr = (exp.startDate.isNotEmpty || exp.endDate.isNotEmpty)
            ? '${exp.startDate} - ${exp.endDate.isEmpty ? "Present" : exp.endDate}'
            : '';

        // Title on left, dates on right
        page.graphics.drawString(
          titleCompany,
          _fontSubHeader,
          brush: PdfSolidBrush(primaryDark),
          bounds: Rect.fromLTWH(0, currentY, pageWidth - 140, 14),
        );
        if (dateStr.isNotEmpty) {
          page.graphics.drawString(
            dateStr,
            _fontMeta,
            brush: PdfSolidBrush(secondarySlate),
            bounds: Rect.fromLTWH(pageWidth - 140, currentY, 140, 14),
            format: PdfStringFormat(alignment: PdfTextAlignment.right),
          );
        }
        currentY += 15;

        if (exp.description.trim().isNotEmpty) {
          final descElement = PdfTextElement(
            text: exp.description.trim(),
            font: _fontBody,
            brush: PdfSolidBrush(textDark),
            format: PdfStringFormat(lineSpacing: 2),
          );
          final layout = descElement.draw(
            page: page,
            bounds:
                Rect.fromLTWH(0, currentY, pageWidth, pageHeight - currentY),
          );
          if (layout != null) {
            page = layout.page;
            currentY = layout.bounds.bottom + 10;
          }
        } else {
          currentY += 6;
        }
      }
      currentY += 4;
    }

    // 5. Education
    if (data.education.isNotEmpty) {
      drawSectionHeader('EDUCATION');
      for (final edu in data.education) {
        checkNewPage(40);
        final degreeInst = edu.institution.isNotEmpty
            ? '${edu.degree}, ${edu.institution}'
            : edu.degree;

        final dateStr = (edu.startYear.isNotEmpty || edu.endYear.isNotEmpty)
            ? '${edu.startYear} - ${edu.endYear}'
            : '';

        page.graphics.drawString(
          degreeInst,
          _fontSubHeader,
          brush: PdfSolidBrush(primaryDark),
          bounds: Rect.fromLTWH(0, currentY, pageWidth - 140, 14),
        );
        if (dateStr.isNotEmpty) {
          page.graphics.drawString(
            dateStr,
            _fontMeta,
            brush: PdfSolidBrush(secondarySlate),
            bounds: Rect.fromLTWH(pageWidth - 140, currentY, 140, 14),
            format: PdfStringFormat(alignment: PdfTextAlignment.right),
          );
        }
        currentY += 15;

        if (edu.description.trim().isNotEmpty) {
          final descElement = PdfTextElement(
            text: edu.description.trim(),
            font: _fontBody,
            brush: PdfSolidBrush(textDark),
            format: PdfStringFormat(lineSpacing: 2),
          );
          final layout = descElement.draw(
            page: page,
            bounds:
                Rect.fromLTWH(0, currentY, pageWidth, pageHeight - currentY),
          );
          if (layout != null) {
            page = layout.page;
            currentY = layout.bounds.bottom + 8;
          }
        } else {
          currentY += 4;
        }
      }
      currentY += 4;
    }

    // 6. Skills
    if (data.skills.isNotEmpty) {
      drawSectionHeader('SKILLS & EXPERTISE');
      checkNewPage(30);
      final skillsText = data.skills.map((s) => '• $s').join('   ');
      final skillsElement = PdfTextElement(
        text: skillsText,
        font: _fontBody,
        brush: PdfSolidBrush(textDark),
        format: PdfStringFormat(lineSpacing: 3),
      );
      final layout = skillsElement.draw(
        page: page,
        bounds: Rect.fromLTWH(0, currentY, pageWidth, pageHeight - currentY),
      );
      if (layout != null) {
        page = layout.page;
        currentY = layout.bounds.bottom + 12;
      }
    }

    // 7. Projects
    if (data.projects.isNotEmpty) {
      drawSectionHeader('KEY PROJECTS');
      for (final proj in data.projects) {
        checkNewPage(40);
        page.graphics.drawString(
          proj.name,
          _fontSubHeader,
          brush: PdfSolidBrush(primaryDark),
          bounds: Rect.fromLTWH(0, currentY, pageWidth, 14),
        );
        currentY += 15;

        if (proj.technologies.trim().isNotEmpty) {
          page.graphics.drawString(
            'Technologies: ${proj.technologies.trim()}',
            _fontMeta,
            brush: PdfSolidBrush(primaryPurple),
            bounds: Rect.fromLTWH(0, currentY, pageWidth, 13),
          );
          currentY += 14;
        }

        if (proj.description.trim().isNotEmpty) {
          final descElement = PdfTextElement(
            text: proj.description.trim(),
            font: _fontBody,
            brush: PdfSolidBrush(textDark),
            format: PdfStringFormat(lineSpacing: 2),
          );
          final layout = descElement.draw(
            page: page,
            bounds:
                Rect.fromLTWH(0, currentY, pageWidth, pageHeight - currentY),
          );
          if (layout != null) {
            page = layout.page;
            currentY = layout.bounds.bottom + 8;
          }
        } else {
          currentY += 4;
        }
      }
      currentY += 4;
    }

    // 8. Certifications
    if (data.certifications.isNotEmpty) {
      drawSectionHeader('CERTIFICATIONS');
      for (final cert in data.certifications) {
        checkNewPage(24);
        final org = cert.organization.isNotEmpty ? ' (${cert.organization})' : '';
        final certLine = '• ${cert.name}$org';
        page.graphics.drawString(
          certLine,
          _fontBodyBold,
          brush: PdfSolidBrush(textDark),
          bounds: Rect.fromLTWH(0, currentY, pageWidth - 100, 14),
        );
        if (cert.date.isNotEmpty) {
          page.graphics.drawString(
            cert.date,
            _fontMeta,
            brush: PdfSolidBrush(textMuted),
            bounds: Rect.fromLTWH(pageWidth - 100, currentY, 100, 14),
            format: PdfStringFormat(alignment: PdfTextAlignment.right),
          );
        }
        currentY += 16;
      }
      currentY += 8;
    }

    // 9. Languages
    if (data.languages.isNotEmpty) {
      drawSectionHeader('LANGUAGES');
      checkNewPage(24);
      final langText = data.languages
          .map((l) => '${l.language} (${l.proficiency})')
          .join('  •  ');
      page.graphics.drawString(
        langText,
        _fontBody,
        brush: PdfSolidBrush(textDark),
        bounds: Rect.fromLTWH(0, currentY, pageWidth, 16),
      );
      currentY += 20;
    }

    // Save PDF file & integrate with storage
    final rawName = customFileName ??
        'CV_${nameStr.replaceAll(RegExp(r'\s+'), '_')}_${DateTime.now().millisecondsSinceEpoch % 10000}';
    return _saveAndRegisterPdf(doc, rawName, customOutputDir: customOutputDir);
  }

  // ===========================================================================
  // 2. COVER LETTER PDF GENERATION
  // ===========================================================================

  Future<File> generateCoverLetterPdf(
    CoverLetterData data, {
    String? customFileName,
    String? customOutputDir,
  }) async {
    final doc = PdfDocument();
    doc.pageSettings.size = PdfPageSize.a4;
    doc.pageSettings.margins.all = 44; // 0.6 inch margins

    PdfPage page = doc.pages.add();
    double currentY = 0;
    final pageWidth = page.getClientSize().width;
    final pageHeight = page.getClientSize().height;

    // 1. Applicant Header
    final applicantName = data.applicantName.trim().isEmpty
        ? 'Your Name'
        : data.applicantName.trim();
    page.graphics.drawString(
      applicantName,
      _fontName,
      brush: PdfSolidBrush(primaryPurple),
      bounds: Rect.fromLTWH(0, currentY, pageWidth, 24),
    );
    currentY += 26;

    final contactLine = [
      if (data.email.trim().isNotEmpty) data.email.trim(),
      if (data.phone.trim().isNotEmpty) data.phone.trim(),
      if (data.address.trim().isNotEmpty) data.address.trim(),
    ].join('  •  ');

    if (contactLine.isNotEmpty) {
      page.graphics.drawString(
        contactLine,
        _fontContact,
        brush: PdfSolidBrush(textMuted),
        bounds: Rect.fromLTWH(0, currentY, pageWidth, 15),
      );
      currentY += 18;
    }

    page.graphics.drawLine(
      PdfPen(dividerColor, width: 1.2),
      Offset(0, currentY),
      Offset(pageWidth, currentY),
    );
    currentY += 18;

    // 2. Date
    final dateStr = data.date.trim().isNotEmpty
        ? data.date.trim()
        : _formatToday();
    page.graphics.drawString(
      dateStr,
      _fontBody,
      brush: PdfSolidBrush(textMuted),
      bounds: Rect.fromLTWH(0, currentY, pageWidth, 14),
    );
    currentY += 20;

    // 3. Recipient Details
    if (data.hiringManagerName.trim().isNotEmpty) {
      page.graphics.drawString(
        data.hiringManagerName.trim(),
        _fontBodyBold,
        brush: PdfSolidBrush(primaryDark),
        bounds: Rect.fromLTWH(0, currentY, pageWidth, 14),
      );
      currentY += 16;
    }

    if (data.companyName.trim().isNotEmpty) {
      page.graphics.drawString(
        data.companyName.trim(),
        _fontBodyBold,
        brush: PdfSolidBrush(textDark),
        bounds: Rect.fromLTWH(0, currentY, pageWidth, 14),
      );
      currentY += 16;
    }

    if (data.jobTitle.trim().isNotEmpty) {
      final jobRef = data.jobReference.trim().isNotEmpty
          ? ' (Ref: ${data.jobReference.trim()})'
          : '';
      page.graphics.drawString(
        'Regarding: ${data.jobTitle.trim()}$jobRef',
        _fontBodyBold,
        brush: PdfSolidBrush(primaryPurple),
        bounds: Rect.fromLTWH(0, currentY, pageWidth, 15),
      );
      currentY += 22;
    } else {
      currentY += 6;
    }

    // 4. Salutation
    final salutation = data.hiringManagerName.trim().isNotEmpty
        ? 'Dear ${data.hiringManagerName.trim()},'
        : 'Dear Hiring Team,';
    page.graphics.drawString(
      salutation,
      _fontBodyBold,
      brush: PdfSolidBrush(textDark),
      bounds: Rect.fromLTWH(0, currentY, pageWidth, 16),
    );
    currentY += 22;

    // Helper for structured paragraphs
    void drawParagraph(String text) {
      if (text.trim().isEmpty) return;
      final element = PdfTextElement(
        text: text.trim(),
        font: _fontBody,
        brush: PdfSolidBrush(textDark),
        format: PdfStringFormat(lineSpacing: 4),
      );
      final layout = element.draw(
        page: page,
        bounds: Rect.fromLTWH(0, currentY, pageWidth, pageHeight - currentY),
      );
      if (layout != null) {
        page = layout.page;
        currentY = layout.bounds.bottom + 14;
      }
    }

    // 5. Letter Body Paragraphs
    drawParagraph(data.introduction);
    drawParagraph(data.skillsExperience);
    drawParagraph(data.whyInterested);
    drawParagraph(data.closingMessage);

    currentY += 10;
    if (currentY + 60 > pageHeight) {
      page = doc.pages.add();
      currentY = 20;
    }

    // 6. Sign-off
    page.graphics.drawString(
      'Sincerely,',
      _fontBody,
      brush: PdfSolidBrush(textDark),
      bounds: Rect.fromLTWH(0, currentY, pageWidth, 16),
    );
    currentY += 34;

    page.graphics.drawString(
      applicantName,
      _fontBodyBold,
      brush: PdfSolidBrush(primaryDark),
      bounds: Rect.fromLTWH(0, currentY, pageWidth, 16),
    );

    final rawName = customFileName ??
        'Cover_Letter_${applicantName.replaceAll(RegExp(r'\s+'), '_')}_${DateTime.now().millisecondsSinceEpoch % 10000}';
    return _saveAndRegisterPdf(doc, rawName, customOutputDir: customOutputDir);
  }

  // ===========================================================================
  // 3. REFERENCE LETTER PDF GENERATION
  // ===========================================================================

  Future<File> generateReferenceLetterPdf(
    ReferenceLetterData data, {
    String? customFileName,
    String? customOutputDir,
  }) async {
    final doc = PdfDocument();
    doc.pageSettings.size = PdfPageSize.a4;
    doc.pageSettings.margins.all = 44;

    PdfPage page = doc.pages.add();
    double currentY = 0;
    final pageWidth = page.getClientSize().width;
    final pageHeight = page.getClientSize().height;

    // 1. Referee / Letterhead Header
    final refereeName = data.refereeName.trim().isEmpty
        ? 'Referee Name'
        : data.refereeName.trim();
    page.graphics.drawString(
      refereeName,
      _fontName,
      brush: PdfSolidBrush(primaryPurple),
      bounds: Rect.fromLTWH(0, currentY, pageWidth, 24),
    );
    currentY += 26;

    final refereeDetails = [
      if (data.refereePosition.trim().isNotEmpty) data.refereePosition.trim(),
      if (data.organization.trim().isNotEmpty) data.organization.trim(),
      if (data.contactInfo.trim().isNotEmpty) data.contactInfo.trim(),
    ].join('  •  ');

    if (refereeDetails.isNotEmpty) {
      page.graphics.drawString(
        refereeDetails,
        _fontContact,
        brush: PdfSolidBrush(textMuted),
        bounds: Rect.fromLTWH(0, currentY, pageWidth, 15),
      );
      currentY += 18;
    }

    page.graphics.drawLine(
      PdfPen(dividerColor, width: 1.2),
      Offset(0, currentY),
      Offset(pageWidth, currentY),
    );
    currentY += 18;

    // 2. Date
    final dateStr =
        data.date.trim().isNotEmpty ? data.date.trim() : _formatToday();
    page.graphics.drawString(
      dateStr,
      _fontBody,
      brush: PdfSolidBrush(textMuted),
      bounds: Rect.fromLTWH(0, currentY, pageWidth, 14),
    );
    currentY += 22;

    // 3. Salutation & Subject
    page.graphics.drawString(
      'To Whom It May Concern:',
      _fontBodyBold,
      brush: PdfSolidBrush(primaryDark),
      bounds: Rect.fromLTWH(0, currentY, pageWidth, 16),
    );
    currentY += 20;

    final appName = data.applicantName.trim().isEmpty
        ? 'the Applicant'
        : data.applicantName.trim();
    final subject = 'SUBJECT: LETTER OF RECOMMENDATION FOR $appName'.toUpperCase();
    page.graphics.drawString(
      subject,
      _fontSubHeader,
      brush: PdfSolidBrush(primaryPurple),
      bounds: Rect.fromLTWH(0, currentY, pageWidth, 16),
    );
    currentY += 22;

    void drawParagraph(String text) {
      if (text.trim().isEmpty) return;
      final element = PdfTextElement(
        text: text.trim(),
        font: _fontBody,
        brush: PdfSolidBrush(textDark),
        format: PdfStringFormat(lineSpacing: 4),
      );
      final layout = element.draw(
        page: page,
        bounds: Rect.fromLTWH(0, currentY, pageWidth, pageHeight - currentY),
      );
      if (layout != null) {
        page = layout.page;
        currentY = layout.bounds.bottom + 14;
      }
    }

    // 4. Structured Recommendation Sections
    final relIntro =
        'I am pleased to write this letter of reference for $appName, who worked as ${data.applicantPosition.trim().isNotEmpty ? data.applicantPosition.trim() : 'a valued team member'} at ${data.organization.trim().isNotEmpty ? data.organization.trim() : 'our organization'}. I have known $appName in my capacity as ${data.relationship.trim().isNotEmpty ? data.relationship.trim() : 'their supervisor/colleague'} for ${data.durationKnown.trim().isNotEmpty ? data.durationKnown.trim() : 'an extended period'}.';
    drawParagraph(relIntro);

    if (data.strengthsSkills.trim().isNotEmpty) {
      drawParagraph(data.strengthsSkills.trim());
    }

    if (data.professionalQualities.trim().isNotEmpty) {
      drawParagraph(data.professionalQualities.trim());
    }

    if (data.additionalComments.trim().isNotEmpty) {
      drawParagraph(data.additionalComments.trim());
    }

    final closing =
        'In summary, $appName has consistently demonstrated exemplary dedication, integrity, and capability. I have no hesitation in giving my highest endorsement for future opportunities. Please feel free to contact me should you require further information.';
    drawParagraph(closing);

    currentY += 10;
    if (currentY + 60 > pageHeight) {
      page = doc.pages.add();
      currentY = 20;
    }

    // 5. Sign-off
    page.graphics.drawString(
      'Sincerely,',
      _fontBody,
      brush: PdfSolidBrush(textDark),
      bounds: Rect.fromLTWH(0, currentY, pageWidth, 16),
    );
    currentY += 34;

    page.graphics.drawString(
      refereeName,
      _fontBodyBold,
      brush: PdfSolidBrush(primaryDark),
      bounds: Rect.fromLTWH(0, currentY, pageWidth, 16),
    );
    currentY += 15;

    if (data.refereePosition.trim().isNotEmpty ||
        data.organization.trim().isNotEmpty) {
      final titleOrg = [data.refereePosition.trim(), data.organization.trim()]
          .where((s) => s.isNotEmpty)
          .join(', ');
      page.graphics.drawString(
        titleOrg,
        _fontBody,
        brush: PdfSolidBrush(textMuted),
        bounds: Rect.fromLTWH(0, currentY, pageWidth, 15),
      );
    }

    final rawName = customFileName ??
        'Reference_Letter_${appName.replaceAll(RegExp(r'\s+'), '_')}_${DateTime.now().millisecondsSinceEpoch % 10000}';
    return _saveAndRegisterPdf(doc, rawName, customOutputDir: customOutputDir);
  }

  // ===========================================================================
  // STORAGE INTEGRATION
  // ===========================================================================

  Future<File> _saveAndRegisterPdf(
    PdfDocument doc,
    String baseName, {
    String? customOutputDir,
  }) async {
    try {
      // 1. Sanitize filename
      var clean = baseName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      if (!clean.toLowerCase().endsWith('.pdf')) {
        clean = '$clean.pdf';
      }

      // 2. Target Application Documents Directory or customOutputDir
      final Directory careerDir;
      if (customOutputDir != null) {
        careerDir = Directory(customOutputDir);
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        careerDir = Directory('${appDir.path}/CareerDocuments');
      }
      if (!careerDir.existsSync()) {
        careerDir.createSync(recursive: true);
      }

      final file = File('${careerDir.path}/$clean');
      final bytes = await doc.save();
      doc.dispose();
      await file.writeAsBytes(bytes, flush: true);

      // 3. Register with DocumentsStorageService
      final docModel = DocumentsModel(
        name: clean,
        path: file.path,
        type: 'pdf',
        createdAt: DateTime.now(),
      );
      await DocumentsStorageService.instance.addDocument(docModel);
      DocumentsStorageService.instance.recordDocumentOpened(docModel);

      debugPrint('[CareerPdfService] Successfully saved & registered: ${file.path}');
      return file;
    } catch (e) {
      doc.dispose();
      debugPrint('[CareerPdfService] Error saving PDF: $e');
      rethrow;
    }
  }

  String _formatToday() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}
