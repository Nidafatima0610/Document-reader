import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:flutter/material.dart';

/// Centralized, beautifully designed confirmation dialogs and actions for
/// "Remove from App" vs "Delete File Permanently", ensuring consistent file safety
/// across all document lists in the app.
class DocumentActionDialogs {
  DocumentActionDialogs._();

  /// Shows confirmation dialog for "Remove from App".
  /// Explains clearly that the document reference is removed from library, recent,
  /// and favorites, but the physical file remains untouched on disk.
  static Future<bool> showRemoveFromAppConfirmation({
    required BuildContext context,
    required DocumentsModel document,
    VoidCallback? onRemoved,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.playlist_remove_rounded, color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Remove from App',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Are you sure you want to remove '${document.name}' from the app?",
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E243A) : const Color(0xFFF7F3FC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF433454) : const Color(0xFFECE3F6),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF7046A8)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "File Safety Notice:\nThis will only remove the document from your app library, Recent history, and Favorites. The actual file will remain safe and untouched on your device.",
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: isDark ? Colors.grey[300] : const Color(0xFF4A3A52),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7046A8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Remove from App'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      final result = await DocumentsStorageService.instance.removeFromApp(document);
      onRemoved?.call();

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(result.message)),
              ],
            ),
          ),
        );
      }
      return true;
    }

    return false;
  }

  /// Shows confirmation dialog for "Delete File Permanently".
  /// Strictly warns that the physical file on storage will be permanently erased.
  static Future<bool> showDeletePermanentlyConfirmation({
    required BuildContext context,
    required DocumentsModel document,
    VoidCallback? onDeleted,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Delete Permanently',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Are you sure you want to permanently delete '${document.name}'?",
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF381B1B) : const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF5A2525) : const Color(0xFFF9C8C8),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Irreversible Action:\nThis will permanently delete the actual file from your device storage and remove all references from the app. You cannot undo this action.",
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: isDark ? Colors.red[200] : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      final result = await DocumentsStorageService.instance.deleteFilePermanently(document);

      if (!context.mounted) return result.success;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (result.success) {
        onDeleted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(result.message)),
              ],
            ),
          ),
        );
        return true;
      } else {
        // Failed: explain issue clearly, NEVER pretend it succeeded
        showDialog(
          context: context,
          builder: (errCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.red),
                SizedBox(width: 10),
                Text('File Deletion Failed'),
              ],
            ),
            content: Text(result.errorMessage ?? result.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(errCtx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return false;
      }
    }

    return false;
  }

  /// Alias for showRemoveFromAppConfirmation
  static Future<bool> showRemoveFromAppDialog({
    required BuildContext context,
    required DocumentsModel document,
    VoidCallback? onRemoved,
  }) => showRemoveFromAppConfirmation(
    context: context,
    document: document,
    onRemoved: onRemoved,
  );

  /// Alias for showDeletePermanentlyConfirmation
  static Future<bool> showDeletePermanentlyDialog({
    required BuildContext context,
    required DocumentsModel document,
    VoidCallback? onDeleted,
  }) => showDeletePermanentlyConfirmation(
    context: context,
    document: document,
    onDeleted: onDeleted,
  );

  /// Builds the standard 3-dot overflow menu items with Open, Details, Favorite,
  /// Remove from App, and Delete File Permanently.
  static List<PopupMenuEntry<String>> buildMenuItems({
    required BuildContext context,
    required DocumentsModel document,
    required bool isSample,
    required bool isFavorite,
  }) {
    return [
      const PopupMenuItem(
        value: 'open',
        child: Row(
          children: [
            Icon(Icons.visibility_outlined, size: 18),
            SizedBox(width: 8),
            Text("Open Document"),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'details',
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text("Document Details")),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'favorite',
        child: Row(
          children: [
            Icon(
              isFavorite ? Icons.star_outline_rounded : Icons.star_rounded,
              size: 18,
              color: Colors.amber,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isFavorite ? "Remove from Favorites" : "Add to Favorites",
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'remove_from_app',
        child: Row(
          children: [
            Icon(Icons.playlist_remove_rounded, size: 18, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(child: Text("Remove from App")),
          ],
        ),
      ),
      if (!isSample && document.path.isNotEmpty)
        const PopupMenuItem(
          value: 'delete_permanently',
          child: Row(
            children: [
              Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Delete File Permanently",
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
    ];
  }
}
