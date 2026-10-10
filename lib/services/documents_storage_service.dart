import 'dart:convert';
import 'dart:io';

import 'package:all_documents_reader/models/documents_model.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DocumentDeleteType { removeFromApp, deletePermanently }

class DocumentDeleteResult {
  final bool success;
  final DocumentDeleteType type;
  final String message;
  final String? errorMessage;
  final bool physicalFileDeleted;

  const DocumentDeleteResult({
    required this.success,
    required this.type,
    required this.message,
    this.errorMessage,
    this.physicalFileDeleted = false,
  });

  factory DocumentDeleteResult.removedFromApp(DocumentsModel document) {
    return DocumentDeleteResult(
      success: true,
      type: DocumentDeleteType.removeFromApp,
      message: "'${document.name}' was removed from the app. Physical file was kept.",
      physicalFileDeleted: false,
    );
  }

  factory DocumentDeleteResult.deletedPermanently(DocumentsModel document) {
    return DocumentDeleteResult(
      success: true,
      type: DocumentDeleteType.deletePermanently,
      message: "'${document.name}' was permanently deleted from device storage.",
      physicalFileDeleted: true,
    );
  }

  factory DocumentDeleteResult.fileMissingRemoved(DocumentsModel document) {
    return DocumentDeleteResult(
      success: true,
      type: DocumentDeleteType.deletePermanently,
      message: "Physical file was already absent from device. Record removed from the app.",
      physicalFileDeleted: false,
    );
  }

  factory DocumentDeleteResult.failure({
    required DocumentDeleteType type,
    required String message,
    required String errorMessage,
  }) {
    return DocumentDeleteResult(
      success: false,
      type: type,
      message: message,
      errorMessage: errorMessage,
      physicalFileDeleted: false,
    );
  }
}

class DocumentsStorageService {
  static final DocumentsStorageService instance =
      DocumentsStorageService._internal();
  DocumentsStorageService._internal();
  factory DocumentsStorageService() => instance;

  static const String _keyDocuments = 'documents';
  static const String _keyFavorites = 'favorite_document_keys';
  static const String _keyRecentDocuments = 'recent_documents';

  final ValueNotifier<Set<String>> favoritesNotifier =
      ValueNotifier<Set<String>>({});

  final ValueNotifier<List<DocumentsModel>> recentDocumentsNotifier =
      ValueNotifier<List<DocumentsModel>>([]);

  final ValueNotifier<List<DocumentsModel>> documentsNotifier =
      ValueNotifier<List<DocumentsModel>>([]);

  Directory? _cachedAppDocumentsDir;

  String normalizeId(String id) {
    if (id.isEmpty) return id;
    return id.replaceAll('\\', '/');
  }

  /// Resolves the app-owned persistent directory for generated files.
  /// Awaits properly without an aggressive 1-second timeout to avoid falling back to temp.
  Future<Directory> getAppDocumentsDirectory() async {
    if (_cachedAppDocumentsDir != null && _cachedAppDocumentsDir!.existsSync()) {
      return _cachedAppDocumentsDir!;
    }
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final target = Directory('${appDir.path}/AppDocuments');
      if (!target.existsSync()) {
        await target.create(recursive: true);
      }
      _cachedAppDocumentsDir = target;
      return target;
    } catch (e) {
      debugPrint('[DocumentsStorageService] Error getting app documents dir: $e');
      final fallback = await getApplicationDocumentsDirectory();
      _cachedAppDocumentsDir = fallback;
      return fallback;
    }
  }

  Future<void> saveDocuments(List<DocumentsModel> documents) async {
    final prefs = await SharedPreferences.getInstance();

    final uniqueDocs = <String, DocumentsModel>{};
    for (final doc in documents) {
      uniqueDocs[normalizeId(doc.id)] = doc;
    }
    final list = uniqueDocs.values.toList();

    final data = list.map((document) => document.toMap()).toList();
    final saved = await prefs.setString(_keyDocuments, jsonEncode(data));

    documentsNotifier.value = list;
    debugPrint("Documents saved: $saved");
  }

  Future<void> addDocument(DocumentsModel document) async {
    final currentDocs = await loadDocuments();
    final targetId = normalizeId(document.id);
    currentDocs.removeWhere((d) => normalizeId(d.id) == targetId);
    currentDocs.insert(0, document);
    await saveDocuments(currentDocs);
  }

  Future<List<DocumentsModel>> loadDocuments() async {
    final prefs = await SharedPreferences.getInstance();

    // Ensure favorites and recent are loaded into notifiers
    await loadFavorites();
    await loadRecentDocuments();

    final data = prefs.getString(_keyDocuments);
    debugPrint('Documents loaded: $data');

    if (data == null) {
      documentsNotifier.value = [];
      return [];
    }

    final List<dynamic> decodedData = jsonDecode(data);
    final currentFavorites = favoritesNotifier.value;

    final loadedList = decodedData.map((item) {
      final doc = DocumentsModel.fromMap(item);
      final isFav = currentFavorites.contains(normalizeId(doc.id)) ||
          currentFavorites.contains(doc.id) ||
          doc.isFavorite;
      return doc.copyWith(isFavorite: isFav);
    }).toList();

    // Deduplicate on load
    final uniqueMap = <String, DocumentsModel>{};
    for (final doc in loadedList) {
      uniqueMap[normalizeId(doc.id)] = doc;
    }
    final deduped = uniqueMap.values.toList();

    documentsNotifier.value = deduped;
    return deduped;
  }

  Future<Set<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList(_keyFavorites) ?? [];
    final favSet = favList.map(normalizeId).toSet();
    favoritesNotifier.value = favSet;
    return favSet;
  }

  bool isFavorite(DocumentsModel document) {
    final normalized = normalizeId(document.id);
    return favoritesNotifier.value.contains(normalized) ||
        favoritesNotifier.value.contains(document.id) ||
        document.isFavorite;
  }

  Future<bool> toggleFavorite(DocumentsModel document) async {
    final prefs = await SharedPreferences.getInstance();
    final currentFavs = Set<String>.from(favoritesNotifier.value);
    final docId = normalizeId(document.id);

    bool newStatus;
    if (currentFavs.contains(docId)) {
      currentFavs.remove(docId);
      newStatus = false;
    } else {
      currentFavs.add(docId);
      newStatus = true;
    }

    favoritesNotifier.value = currentFavs;
    await prefs.setStringList(_keyFavorites, currentFavs.toList());

    // Also sync saved documents list if this is a user-saved document
    final data = prefs.getString(_keyDocuments);
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      final updatedList = decoded.map((item) {
        final doc = DocumentsModel.fromMap(item);
        if (normalizeId(doc.id) == docId) {
          return doc.copyWith(isFavorite: newStatus).toMap();
        }
        return item;
      }).toList();
      await prefs.setString(_keyDocuments, jsonEncode(updatedList));

      final updatedDocs = documentsNotifier.value.map((doc) {
        if (normalizeId(doc.id) == docId) {
          return doc.copyWith(isFavorite: newStatus);
        }
        return doc;
      }).toList();
      documentsNotifier.value = updatedDocs;
    }

    // Also update recent documents list favorite flags
    final currentRecents = List<DocumentsModel>.from(
      recentDocumentsNotifier.value,
    );
    final updatedRecents = currentRecents.map((doc) {
      if (normalizeId(doc.id) == docId) {
        return doc.copyWith(isFavorite: newStatus);
      }
      return doc;
    }).toList();
    recentDocumentsNotifier.value = updatedRecents;
    await _saveRecentList(updatedRecents);

    debugPrint("Toggled favorite for '$docId': $newStatus");
    return newStatus;
  }

  // --- Safe Document Deletion Logic ---

  /// Removes the document reference from the app's library, favorites, and recent history.
  /// Physical file remains untouched on disk.
  Future<DocumentDeleteResult> removeFromApp(DocumentsModel document) async {
    await _removeReferencesFromApp(document);
    debugPrint("[DocumentsStorageService] Removed '${document.name}' from app listing.");
    return DocumentDeleteResult.removedFromApp(document);
  }

  /// Deletes the physical file permanently after explicit user confirmation,
  /// and removes its references across the app.
  /// If the file cannot be deleted (e.g. permission restriction), the app reference is KEPT
  /// and an error result is returned to prevent false success.
  Future<DocumentDeleteResult> deleteFilePermanently(DocumentsModel document) async {
    if (document.path.trim().isEmpty) {
      return DocumentDeleteResult.failure(
        type: DocumentDeleteType.deletePermanently,
        message: "Cannot delete preview document.",
        errorMessage: "This is a sample preview document with no local file to delete.",
      );
    }

    // 1. Validate canonical path and ensure it is not a directory or system folder
    final targetFile = File(document.path);
    String canonicalPath = targetFile.absolute.path;
    try {
      canonicalPath = targetFile.resolveSymbolicLinksSync();
    } catch (_) {
      // Fallback to absolute path if symlink resolution is not supported
    }

    // Safety checks: ensure it is not a directory
    try {
      if (FileSystemEntity.isDirectorySync(canonicalPath)) {
        return DocumentDeleteResult.failure(
          type: DocumentDeleteType.deletePermanently,
          message: "Operation rejected for safety.",
          errorMessage: "The target path is a directory, not a document file.",
        );
      }
    } catch (_) {}

    // Check system root protection
    if (canonicalPath == '/' ||
        canonicalPath == 'C:\\' ||
        canonicalPath.toLowerCase().startsWith('c:\\windows') ||
        canonicalPath.toLowerCase().startsWith('/system')) {
      return DocumentDeleteResult.failure(
        type: DocumentDeleteType.deletePermanently,
        message: "Operation rejected for safety.",
        errorMessage: "Cannot delete system files or root directories.",
      );
    }

    // 2. Check if file exists on disk
    if (!targetFile.existsSync()) {
      // The physical file is already gone/missing from device storage
      await _removeReferencesFromApp(document);
      return DocumentDeleteResult.fileMissingRemoved(document);
    }

    // 3. Attempt physical deletion
    try {
      await targetFile.delete();
      debugPrint("[DocumentsStorageService] Physically deleted file: ${targetFile.path}");
    } catch (e) {
      debugPrint("[DocumentsStorageService] Failed to delete file: $e");
      return DocumentDeleteResult.failure(
        type: DocumentDeleteType.deletePermanently,
        message: "Could not delete '${document.name}' from device storage.",
        errorMessage:
            "Android storage permissions prevented permanent deletion of this file ($e). The file is still on your device, and its listing was retained. You can use 'Remove from App' instead if you only wish to hide it.",
      );
    }

    // 4. Physical deletion succeeded: remove references from app
    await _removeReferencesFromApp(document);
    return DocumentDeleteResult.deletedPermanently(document);
  }

  /// Helper to remove document metadata across documents list, favorites, and recents
  Future<void> _removeReferencesFromApp(DocumentsModel document) async {
    final prefs = await SharedPreferences.getInstance();
    final docId = normalizeId(document.id);

    // 1. Remove from saved documents
    final data = prefs.getString(_keyDocuments);
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      final updatedList = decoded.where((item) {
        final doc = DocumentsModel.fromMap(item);
        return normalizeId(doc.id) != docId;
      }).toList();
      await prefs.setString(_keyDocuments, jsonEncode(updatedList));
    }
    final currentDocs = List<DocumentsModel>.from(documentsNotifier.value);
    currentDocs.removeWhere((doc) => normalizeId(doc.id) == docId);
    documentsNotifier.value = currentDocs;

    // 2. Remove from favorites
    final currentFavs = Set<String>.from(favoritesNotifier.value);
    if (currentFavs.contains(docId) || currentFavs.contains(document.id)) {
      currentFavs.remove(docId);
      currentFavs.remove(document.id);
      favoritesNotifier.value = currentFavs;
      await prefs.setStringList(_keyFavorites, currentFavs.toList());
    }

    // 3. Remove from recent documents
    final currentRecents = List<DocumentsModel>.from(
      recentDocumentsNotifier.value,
    );
    currentRecents.removeWhere((doc) => normalizeId(doc.id) == docId);
    recentDocumentsNotifier.value = currentRecents;
    await _saveRecentList(currentRecents);
  }

  /// Backward-compatible delete method (performs safe removal from app)
  Future<void> deleteDocument(DocumentsModel document) async {
    await removeFromApp(document);
  }

  // --- Recent Documents Tracking ---

  Future<List<DocumentsModel>> loadRecentDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyRecentDocuments);

    if (data == null || data.isEmpty) {
      recentDocumentsNotifier.value = [];
      return [];
    }

    try {
      final List<dynamic> decodedData = jsonDecode(data);
      final currentFavorites = favoritesNotifier.value;

      final list = decodedData.map((item) {
        final doc = DocumentsModel.fromMap(item);
        final isFav = currentFavorites.contains(normalizeId(doc.id)) ||
            currentFavorites.contains(doc.id) ||
            doc.isFavorite;
        return doc.copyWith(isFavorite: isFav);
      }).toList();

      // Deduplicate on load
      final uniqueMap = <String, DocumentsModel>{};
      for (final doc in list) {
        uniqueMap[normalizeId(doc.id)] = doc;
      }
      final deduped = uniqueMap.values.toList();

      recentDocumentsNotifier.value = deduped;
      return deduped;
    } catch (e) {
      debugPrint("Error loading recent documents: $e");
      recentDocumentsNotifier.value = [];
      return [];
    }
  }

  Future<void> recordDocumentOpened(DocumentsModel document) async {
    final openedDoc = document.copyWith(
      lastOpenedAt: DateTime.now(),
      isFavorite: isFavorite(document),
    );

    final currentRecents = List<DocumentsModel>.from(
      recentDocumentsNotifier.value,
    );

    final targetId = normalizeId(openedDoc.id);

    // Remove if already present (to avoid duplicates)
    currentRecents.removeWhere((doc) => normalizeId(doc.id) == targetId);

    // Insert at top of list
    currentRecents.insert(0, openedDoc);

    // Limit to latest 10 documents
    final trimmedList = currentRecents.length > 10
        ? currentRecents.sublist(0, 10)
        : currentRecents;

    recentDocumentsNotifier.value = trimmedList;
    await _saveRecentList(trimmedList);

    debugPrint(
      "Recorded document open: '${openedDoc.name}' (Total recent: ${trimmedList.length})",
    );
  }

  Future<void> removeRecentDocument(DocumentsModel document) async {
    final currentRecents = List<DocumentsModel>.from(
      recentDocumentsNotifier.value,
    );
    final targetId = normalizeId(document.id);
    currentRecents.removeWhere((doc) => normalizeId(doc.id) == targetId);
    recentDocumentsNotifier.value = currentRecents;
    await _saveRecentList(currentRecents);
  }

  Future<void> clearRecentDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    recentDocumentsNotifier.value = [];
    await prefs.remove(_keyRecentDocuments);
    debugPrint("Cleared all recent documents history");
  }

  Future<void> _saveRecentList(List<DocumentsModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    final data = list.map((doc) => doc.toMap()).toList();
    await prefs.setString(_keyRecentDocuments, jsonEncode(data));
  }
}
