import 'dart:convert';

import 'package:all_documents_reader/models/documents_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DocumentsStorageService {
  Future<void> saveDocuments(List<DocumentsModel> documents) async {
    final prefs = await SharedPreferences.getInstance();

    final data = documents.map((document) => document.toMap()).toList();
    final saved = await prefs.setString('documents', jsonEncode(data));

    print("Documents saved: $saved");
  }

  Future<List<DocumentsModel>> loadDocuments() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString('documents');
    print('Documents loaded: $data');

    if (data == null) {
      return [];
    }

    final List<dynamic> decodedData = jsonDecode(data);

    return decodedData.map((item) => DocumentsModel.fromMap(item)).toList();
  }
}
