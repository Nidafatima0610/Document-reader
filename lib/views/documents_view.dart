import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/widgets/documents_app_bar.dart';
import 'package:all_documents_reader/widgets/documents_body.dart';
import 'package:all_documents_reader/widgets/documents_fab.dart';
import 'package:flutter/material.dart';

class DocumentsView extends StatefulWidget {
  final String? initialCategory;
  final String? initialSearchQuery;

  const DocumentsView({
    super.key,
    this.initialCategory,
    this.initialSearchQuery,
  });

  @override
  State<DocumentsView> createState() => _DocumentsViewState();
}

class _DocumentsViewState extends State<DocumentsView> {
  final List<DocumentsModel> documents = [];
  final DocumentsStorageService storageService = DocumentsStorageService();

  Future<void> loadDocuments() async {
    final savedDocuments = await storageService.loadDocuments();
    if (!mounted) return;
    setState(() {
      documents.clear();
      documents.addAll(savedDocuments);
    });
  }

  void _syncNotifierDocs() {
    if (!mounted) return;
    setState(() {
      documents.clear();
      documents.addAll(storageService.documentsNotifier.value);
    });
  }

  @override
  void initState() {
    super.initState();
    loadDocuments();
    storageService.documentsNotifier.addListener(_syncNotifierDocs);
  }

  @override
  void dispose() {
    storageService.documentsNotifier.removeListener(_syncNotifierDocs);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DocumentsAppBar(
        totalCount: documents.length + 6, // user added + sample documents
        onRefresh: loadDocuments,
      ),
      body: DocumentsBody(
        documents: documents,
        initialCategory: widget.initialCategory,
        initialSearchQuery: widget.initialSearchQuery,
        onDocumentDelete: (document) async {
          setState(() {
            documents.remove(document);
          });

          await storageService.deleteDocument(document);
        },
      ),
      floatingActionButton: DocumentsFab(
        onDocumentPicked: (document) async {
          await storageService.addDocument(document);
          await loadDocuments();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                duration: const Duration(milliseconds: 2000),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text("Added '${document.name}' to Documents"),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
