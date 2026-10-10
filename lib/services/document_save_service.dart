import 'dart:io';
import 'dart:typed_data';

import 'package:all_documents_reader/models/documents_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

class DocumentSaveResult {
  final bool success;
  final bool cancelled;
  final String? savedPath;
  final String? fileName;
  final String? errorMessage;

  const DocumentSaveResult({
    required this.success,
    required this.cancelled,
    this.savedPath,
    this.fileName,
    this.errorMessage,
  });

  factory DocumentSaveResult.success({
    required String savedPath,
    required String fileName,
  }) {
    return DocumentSaveResult(
      success: true,
      cancelled: false,
      savedPath: savedPath,
      fileName: fileName,
    );
  }

  factory DocumentSaveResult.cancelled() {
    return const DocumentSaveResult(
      success: false,
      cancelled: true,
    );
  }

  factory DocumentSaveResult.failure(String errorMessage) {
    return DocumentSaveResult(
      success: false,
      cancelled: false,
      errorMessage: errorMessage,
    );
  }
}

class DocumentSaveService {
  DocumentSaveService._internal();
  static final DocumentSaveService instance = DocumentSaveService._internal();
  factory DocumentSaveService() => instance;

  /// Prompts user to customize filename and uses Android Storage Access Framework
  /// (FilePicker saveFile) to select destination and save PDF bytes.
  Future<DocumentSaveResult> saveDocumentToDevice({
    required BuildContext context,
    required File sourceFile,
    required String defaultFileName,
    DocumentsModel? document,
  }) => savePdfToDevice(
    context: context,
    sourceFile: sourceFile,
    defaultFileName: defaultFileName,
    document: document,
  );

  /// Prompts user to customize filename and uses Android Storage Access Framework
  /// (FilePicker saveFile) to select destination and save PDF bytes.
  Future<DocumentSaveResult> savePdfToDevice({
    required BuildContext context,
    required File sourceFile,
    required String defaultFileName,
    DocumentsModel? document,
  }) async {
    if (!sourceFile.existsSync()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Cannot save: Source PDF file not found on disk.'),
          ),
        );
      }
      return DocumentSaveResult.failure('Source file does not exist.');
    }

    // 1. Prepare sensible default filename
    var cleanName = defaultFileName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (!cleanName.toLowerCase().endsWith('.pdf')) {
      cleanName = '$cleanName.pdf';
    }

    // 2. Prompt user with filename dialog allowing customization before system picker
    final chosenName = await _showFilenameDialog(context, cleanName);
    if (chosenName == null || chosenName.trim().isEmpty) {
      // User cancelled filename dialog
      return DocumentSaveResult.cancelled();
    }

    var finalFileName = chosenName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (!finalFileName.toLowerCase().endsWith('.pdf')) {
      finalFileName = '$finalFileName.pdf';
    }

    try {
      final Uint8List pdfBytes = await sourceFile.readAsBytes();
      if (pdfBytes.isEmpty) {
        throw const FormatException('PDF file is empty (0 bytes).');
      }

      // 3. Open Android Storage Access Framework / System File Picker
      final Uri? selectedUri = await FilePicker.saveFile(
        dialogTitle: 'Save PDF to Device',
        fileName: finalFileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: pdfBytes,
      );

      if (selectedUri == null) {
        // User cancelled destination picker in system UI
        debugPrint('[DocumentSaveService] User cancelled save picker');
        return DocumentSaveResult.cancelled();
      }

      String selectedPath;
      try {
        selectedPath = selectedUri.toFilePath();
      } catch (_) {
        selectedPath = selectedUri.path.isNotEmpty ? selectedUri.path : selectedUri.toString();
      }

      // 4. Verify save completion
      // If selectedPath is a filesystem path, verify or write bytes if needed
      final targetFile = File(selectedPath);
      if (targetFile.existsSync()) {
        if (targetFile.lengthSync() == 0) {
          await targetFile.writeAsBytes(pdfBytes, flush: true);
        }
      } else {
        try {
          await targetFile.writeAsBytes(pdfBytes, flush: true);
        } catch (_) {
          // May be a content URI on Android handled directly by the plugin
        }
      }

      final friendlyPath = _formatFriendlyLocation(selectedPath);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Saved '$finalFileName'",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  "Location: $friendlyPath",
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.amberAccent,
              onPressed: () {
                OpenFilex.open(selectedPath);
              },
            ),
          ),
        );
      }

      return DocumentSaveResult.success(
        savedPath: selectedPath,
        fileName: finalFileName,
      );
    } catch (e) {
      debugPrint('[DocumentSaveService] Save failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade800,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Failed to save to device: $e'),
                ),
              ],
            ),
          ),
        );
      }
      return DocumentSaveResult.failure(e.toString());
    }
  }

  Future<String?> _showFilenameDialog(BuildContext context, String initialName) async {
    final textController = TextEditingController(text: initialName);
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.save_alt_rounded, color: Color(0xFF7046A8)),
              SizedBox(width: 10),
              Text('Save to Device', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose a filename for the PDF document:',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : const Color(0xFF4A3A52),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: textController,
                  autofocus: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 20),
                    hintText: 'Document name...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF7046A8), width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a filename';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'You will choose the destination folder (Downloads, Drive, etc.) in the next step.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7046A8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogCtx, textController.text.trim());
                }
              },
              child: const Text('Choose Destination'),
            ),
          ],
        );
      },
    );
  }

  String _formatFriendlyLocation(String path) {
    if (path.contains('/Download')) return 'Downloads folder';
    if (path.contains('/Documents')) return 'Documents folder';
    if (path.startsWith('content://')) return 'Selected Device Storage';
    return path;
  }

  /// Generates a unique file name in the specified directory to prevent accidental overwrites
  String generateUniqueFileName({required Directory directory, required String baseName}) {
    final file = File('${directory.path}/$baseName');
    if (!file.existsSync()) return baseName;

    final dotIndex = baseName.lastIndexOf('.');
    final nameWithoutExt = dotIndex != -1 ? baseName.substring(0, dotIndex) : baseName;
    final ext = dotIndex != -1 ? baseName.substring(dotIndex) : '';

    int counter = 1;
    while (true) {
      final candidate = '$nameWithoutExt ($counter)$ext';
      if (!File('${directory.path}/$candidate').existsSync()) {
        return candidate;
      }
      counter++;
    }
  }
}
