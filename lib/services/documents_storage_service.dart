import 'dart:convert';

import 'package:all_documents_reader/models/documents_model.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> saveDocuments(List<DocumentsModel> documents) async {
    final prefs = await SharedPreferences.getInstance();

    final uniqueDocs = <String, DocumentsModel>{};
    for (final doc in documents) {
      uniqueDocs[doc.id] = doc;
    }
    final list = uniqueDocs.values.toList();

    final data = list.map((document) => document.toMap()).toList();
    final saved = await prefs.setString(_keyDocuments, jsonEncode(data));

    documentsNotifier.value = list;
    debugPrint("Documents saved: $saved");
  }

  Future<void> addDocument(DocumentsModel document) async {
    final currentDocs = await loadDocuments();
    currentDocs.removeWhere((d) => d.id == document.id);
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
      final isFav = currentFavorites.contains(doc.id) || doc.isFavorite;
      return doc.copyWith(isFavorite: isFav);
    }).toList();

    documentsNotifier.value = loadedList;
    return loadedList;
  }

  Future<Set<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList(_keyFavorites) ?? [];
    final favSet = favList.toSet();
    favoritesNotifier.value = favSet;
    return favSet;
  }

  bool isFavorite(DocumentsModel document) {
    return favoritesNotifier.value.contains(document.id) || document.isFavorite;
  }

  Future<bool> toggleFavorite(DocumentsModel document) async {
    final prefs = await SharedPreferences.getInstance();
    final currentFavs = Set<String>.from(favoritesNotifier.value);
    final docId = document.id;

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
        if (doc.id == docId) {
          return doc.copyWith(isFavorite: newStatus).toMap();
        }
        return item;
      }).toList();
      await prefs.setString(_keyDocuments, jsonEncode(updatedList));
    }

    // Also update recent documents list favorite flags
    final currentRecents = List<DocumentsModel>.from(
      recentDocumentsNotifier.value,
    );
    final updatedRecents = currentRecents.map((doc) {
      if (doc.id == docId) {
        return doc.copyWith(isFavorite: newStatus);
      }
      return doc;
    }).toList();
    recentDocumentsNotifier.value = updatedRecents;
    await _saveRecentList(updatedRecents);

    debugPrint("Toggled favorite for '$docId': $newStatus");
    return newStatus;
  }

  // --- Delete Document Across All Storage & History ---

  Future<void> deleteDocument(DocumentsModel document) async {
    final prefs = await SharedPreferences.getInstance();
    final docId = document.id;

    // 1. Remove from saved documents
    final data = prefs.getString(_keyDocuments);
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      final updatedList = decoded.where((item) {
        final doc = DocumentsModel.fromMap(item);
        return doc.id != docId;
      }).toList();
      await prefs.setString(_keyDocuments, jsonEncode(updatedList));

      final currentDocs = List<DocumentsModel>.from(documentsNotifier.value);
      currentDocs.removeWhere((doc) => doc.id == docId);
      documentsNotifier.value = currentDocs;
    }

    // 2. Remove from favorites
    final currentFavs = Set<String>.from(favoritesNotifier.value);
    if (currentFavs.contains(docId)) {
      currentFavs.remove(docId);
      favoritesNotifier.value = currentFavs;
      await prefs.setStringList(_keyFavorites, currentFavs.toList());
    }

    // 3. Remove from recent documents
    final currentRecents = List<DocumentsModel>.from(
      recentDocumentsNotifier.value,
    );
    currentRecents.removeWhere((doc) => doc.id == docId);
    recentDocumentsNotifier.value = currentRecents;
    await _saveRecentList(currentRecents);

    debugPrint(
      "Deleted document '$docId' from documents, favorites, and recent history",
    );
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
        final isFav = currentFavorites.contains(doc.id) || doc.isFavorite;
        return doc.copyWith(isFavorite: isFav);
      }).toList();

      recentDocumentsNotifier.value = list;
      return list;
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

    // Remove if already present (to avoid duplicates)
    currentRecents.removeWhere((doc) => doc.id == openedDoc.id);

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
    currentRecents.removeWhere((doc) => doc.id == document.id);
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
