import 'dart:io';
import 'package:all_documents_reader/core/theme/app_theme.dart';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/views/career_cover_letter_view.dart';
import 'package:all_documents_reader/views/career_reference_letter_view.dart';
import 'package:all_documents_reader/views/career_resume_builder_view.dart';
import 'package:all_documents_reader/views/pdf_viewer_screen.dart';
import 'package:all_documents_reader/services/document_save_service.dart';
import 'package:all_documents_reader/widgets/document_action_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Landing page for the 6th navigation tab: Career Documents.
/// Houses the CV/Resume Builder, Cover Letter Generator, and Reference Letter Generator.
class CareerView extends StatelessWidget {
  const CareerView({super.key});

  void _openDocument(BuildContext context, DocumentsModel doc) {
    if (doc.path.isEmpty || !File(doc.path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("File '${doc.name}' not found on device storage."),
        ),
      );
      return;
    }

    DocumentsStorageService.instance.recordDocumentOpened(doc);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          file: File(doc.path),
          title: doc.name,
          document: doc,
        ),
      ),
    );
  }

  bool _isCareerDocument(DocumentsModel doc) {
    final lower = doc.name.toLowerCase();
    return lower.contains('cv_') ||
        lower.contains('resume_') ||
        lower.contains('cover_letter_') ||
        lower.contains('reference_letter_') ||
        doc.path.contains('CareerDocuments');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.work_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Career Documents",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: isDark ? Colors.white : const Color(0xFF251E2D),
                    ),
                  ),
                  Text(
                    "Create professional documents for your career.",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFFB5A7C2)
                          : const Color(0xFF786F80),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. Featured Header Hero Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF381F54), const Color(0xFF26153B)]
                    : [const Color(0xFF7046A8), const Color(0xFF5E35B1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPurple.withValues(alpha: isDark ? 0.3 : 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '100% OFFLINE & PRIVATE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Career Documents Hub',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Generate publication-ready resumes, cover letters, and reference letters directly as PDFs.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 2. Main Feature Cards Header
          Text(
            "Document Builders",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: isDark ? Colors.white : const Color(0xFF251E2D),
            ),
          ),
          const SizedBox(height: 12),

          // Feature Card 1: CV / Resume Builder
          _buildFeatureCard(
            context: context,
            title: "CV / Resume Builder",
            subtitle:
                "Create a comprehensive, modern resume with work experience, education, skills, projects, and certifications.",
            badgeText: "Multi-Section",
            icon: Icons.badge_rounded,
            accentColor: AppTheme.primaryPurple,
            lightBg: const Color(0xFFF7F1FB),
            darkBg: const Color(0xFF281E34),
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CareerResumeBuilderView(),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // Feature Card 2: Cover Letter
          _buildFeatureCard(
            context: context,
            title: "Cover Letter",
            subtitle:
                "Craft targeted job application letters with custom employer details, role matching, and professional letterhead.",
            badgeText: "Standard Format",
            icon: Icons.mark_email_read_rounded,
            accentColor: const Color(0xFF1E88E5),
            lightBg: const Color(0xFFF0F5FC),
            darkBg: const Color(0xFF1A2738),
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CareerCoverLetterView(),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // Feature Card 3: Reference Letter
          _buildFeatureCard(
            context: context,
            title: "Reference Letter",
            subtitle:
                "Create formal recommendation and endorsement letters with referee credentials, relationship context, and signature block.",
            badgeText: "Formal Letterhead",
            icon: Icons.verified_user_rounded,
            accentColor: const Color(0xFF00897B),
            lightBg: const Color(0xFFF0F9FA),
            darkBg: const Color(0xFF182E2B),
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CareerReferenceLetterView(),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // 3. Recent Career Documents Header
          Text(
            "Saved Career Documents",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: isDark ? Colors.white : const Color(0xFF251E2D),
            ),
          ),
          const SizedBox(height: 10),

          // 4. Dynamic Recent Documents List
          ValueListenableBuilder<List<DocumentsModel>>(
            valueListenable: DocumentsStorageService.instance.documentsNotifier,
            builder: (context, allDocs, _) {
              final careerDocs = allDocs.where(_isCareerDocument).toList();

              if (careerDocs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF211C29) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2E2638)
                          : const Color(0xFFECE4F5),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple
                              .withValues(alpha: isDark ? 0.2 : 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.folder_shared_rounded,
                          size: 28,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "No Career Documents Yet",
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF251E2D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Generated CVs, cover letters, and reference letters will appear here.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey[400]
                              : const Color(0xFF786F80),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: careerDocs.map((doc) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF211C29) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2E2638)
                            : const Color(0xFFEDE5F4),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.2 : 0.025),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.pdfColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: AppTheme.pdfColor,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        doc.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF251E2D),
                        ),
                      ),
                      subtitle: Text(
                        'PDF Document • Saved',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? Colors.grey[400]
                              : const Color(0xFF786F80),
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        onSelected: (value) async {
                          if (value == 'open') {
                            _openDocument(context, doc);
                          } else if (value == 'save') {
                            if (File(doc.path).existsSync()) {
                              await DocumentSaveService.instance.saveDocumentToDevice(
                                context: context,
                                sourceFile: File(doc.path),
                                defaultFileName: doc.name,
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("File '${doc.name}' not found on device."),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else if (value == 'share') {
                            if (File(doc.path).existsSync()) {
                              // ignore: deprecated_member_use
                              await Share.shareXFiles(
                                [XFile(doc.path)],
                                subject: doc.name,
                              );
                            }
                          } else if (value == 'remove') {
                            await DocumentActionDialogs.showRemoveFromAppDialog(
                              context: context,
                              document: doc,
                            );
                          } else if (value == 'delete') {
                            await DocumentActionDialogs.showDeletePermanentlyDialog(
                              context: context,
                              document: doc,
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'open',
                            child: Row(
                              children: [
                                Icon(Icons.visibility_outlined, size: 20),
                                SizedBox(width: 10),
                                Text('Open'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'save',
                            child: Row(
                              children: [
                                Icon(Icons.save_alt_rounded, size: 20),
                                SizedBox(width: 10),
                                Text('Save to Device'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share_outlined, size: 20),
                                SizedBox(width: 10),
                                Text('Share'),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.remove_circle_outline_rounded, size: 20),
                                SizedBox(width: 10),
                                Text('Remove from App'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_forever_rounded, color: Colors.red.shade700, size: 20),
                                SizedBox(width: 10),
                                Text('Delete File Permanently', style: TextStyle(color: Colors.red.shade700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _openDocument(context, doc),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String badgeText,
    required IconData icon,
    required Color accentColor,
    required Color lightBg,
    required Color darkBg,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF211B28) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF2E2638)
                  : accentColor.withValues(alpha: 0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : accentColor.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? accentColor.withValues(alpha: 0.2)
                      : accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF261E2D),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(
                                alpha: isDark ? 0.22 : 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isDark
                            ? Colors.grey[400]
                            : const Color(0xFF6E6476),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Open Builder',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: accentColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
