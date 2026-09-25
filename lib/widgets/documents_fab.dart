import 'package:all_documents_reader/core/theme/app_theme.dart';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class DocumentsFab extends StatelessWidget {
  final Function(DocumentsModel) onDocumentPicked;

  const DocumentsFab({super.key, required this.onDocumentPicked});

  static bool _isPicking = false;

  String getDocumentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    if (extension == 'pdf') {
      return 'pdf';
    }

    if ([
      'doc',
      'docx',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
      'txt',
      'rtf',
      'csv',
    ].contains(extension)) {
      return 'office';
    }

    if ([
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
      'bmp',
      'svg',
    ].contains(extension)) {
      return 'image';
    }

    return 'other';
  }

  Future<void> _pickFiles({
    required BuildContext context,
    required FileType fileType,
    List<String>? allowedExtensions,
  }) async {
    if (_isPicking) return;
    _isPicking = true;

    // Dismiss bottom sheet immediately upon selection so double taps cannot occur
    if (context.mounted) {
      Navigator.pop(context);
    }

    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
      );

      if (files.isEmpty) {
        return;
      }

      final file = files.first;

      final document = DocumentsModel(
        name: file.name,
        path: file.path ?? '',
        type: getDocumentType(file.name),
        createdAt: DateTime.now(),
      );

      onDocumentPicked(document);
    } catch (e) {
      debugPrint("Error picking file: $e");
    } finally {
      _isPicking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FloatingActionButton.extended(
      elevation: 4,
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(Icons.add_rounded, size: 22),
      label: const Text(
        "Add Document",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: isDark ? const Color(0xFF211C29) : Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: isDark ? const Color(0xFF4C3E5B) : Colors.grey.shade300,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Import Document",
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF2D2435),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildImportOption(
                      context: context,
                      title: "PDF Document",
                      subtitle: "Select Adobe PDF files (.pdf)",
                      icon: Icons.picture_as_pdf_rounded,
                      iconColor: AppTheme.pdfColor,
                      bgColor: isDark
                          ? const Color(0xFF381A1A)
                          : const Color(0xFFFDE8E8),
                      onTap: () => _pickFiles(
                        context: context,
                        fileType: FileType.custom,
                        allowedExtensions: ["pdf"],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildImportOption(
                      context: context,
                      title: "Office Document",
                      subtitle: "Word, Excel, PowerPoint, Text",
                      icon: Icons.table_chart_rounded,
                      iconColor: AppTheme.excelColor,
                      bgColor: isDark
                          ? const Color(0xFF19361C)
                          : const Color(0xFFE8F5E9),
                      onTap: () => _pickFiles(
                        context: context,
                        fileType: FileType.custom,
                        allowedExtensions: [
                          "doc",
                          "docx",
                          "xls",
                          "xlsx",
                          "ppt",
                          "pptx",
                          "txt",
                          "rtf",
                          "csv",
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildImportOption(
                      context: context,
                      title: "Image Document",
                      subtitle: "Photos, Scans & Screenshots (.jpg, .png)",
                      icon: Icons.image_rounded,
                      iconColor: AppTheme.imageColor,
                      bgColor: isDark
                          ? const Color(0xFF102E33)
                          : const Color(0xFFE0F7FA),
                      onTap: () => _pickFiles(
                        context: context,
                        fileType: FileType.image,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildImportOption(
                      context: context,
                      title: "Any Other File",
                      subtitle: "Browse all file formats on device",
                      icon: Icons.folder_open_rounded,
                      iconColor: AppTheme.primaryColor,
                      bgColor: isDark
                          ? const Color(0xFF2C1E40)
                          : const Color(0xFFF1E7FA),
                      onTap: () =>
                          _pickFiles(context: context, fileType: FileType.any),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildImportOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF332B3D) : const Color(0xFFEFE8F7),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF2D2435),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey[400]
                            : const Color(0xFF6B6570),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
