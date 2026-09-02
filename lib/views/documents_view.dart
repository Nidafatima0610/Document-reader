import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/widgets/documents_app_bar.dart';
import 'package:all_documents_reader/widgets/documents_body.dart';
import 'package:all_documents_reader/widgets/documents_fab.dart';
import 'package:flutter/material.dart';

class DocumentsView extends StatefulWidget {
  const DocumentsView({super.key});

  @override
  State<DocumentsView> createState() => _DocumentsViewState();
}

class _DocumentsViewState extends State<DocumentsView> {
  final List<DocumentsModel> documents = [];
  final DocumentsStorageService storageService = DocumentsStorageService();
  Future<void> loadDocuments() async {
    final savedDocuments = await storageService.loadDocuments();
    setState(() {
      documents.addAll(savedDocuments);
    });
  }

  @override
  void initState() {
    super.initState();
    loadDocuments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DocumentsAppBar(),
      body: DocumentsBody(
        documents: documents,
        onDocumentDelete: (document) async {
          setState(() {
            documents.remove(document);
          });

          await storageService.saveDocuments(documents);
        },
      ),
      floatingActionButton: DocumentsFab(
        onDocumentPicked: (document) async {
          setState(() {
            documents.add(document);
          });

          await storageService.saveDocuments(documents);
        },
      ),
    );
  }
}
