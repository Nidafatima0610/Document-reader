import 'dart:io';

import 'package:all_documents_reader/models/documents_model.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class DocumentsBody extends StatefulWidget {
  final List<DocumentsModel> documents;
  final Function(DocumentsModel) onDocumentDelete;
  const DocumentsBody({
    super.key,
    required this.documents,
    required this.onDocumentDelete,
  });

  @override
  State<DocumentsBody> createState() => _DocumentsBodyState();
}

class _DocumentsBodyState extends State<DocumentsBody> {
  final TextEditingController searchController = TextEditingController();
  final TransformationController imageController = TransformationController();
  String selectedType = 'all';
  final List<DocumentsModel> sampleDocuments = [
    DocumentsModel(
      name: 'Sample Document.pdf',
      path: '',
      type: 'pdf',
      createdAt: DateTime(2020, 1, 1),
    ),
    DocumentsModel(
      name: 'Budget.xlsx',
      path: '',
      type: 'office',
      createdAt: DateTime(2020, 1, 2),
    ),
    DocumentsModel(
      name: 'Assignment.docx',
      path: '',
      type: 'office',
      createdAt: DateTime(2020, 1, 3),
    ),
    DocumentsModel(
      name: 'Presentation.pptx',
      path: '',
      type: 'office',
      createdAt: DateTime(2020, 1, 4),
    ),
    DocumentsModel(
      name: 'Notes.txt',
      path: '',
      type: 'office',
      createdAt: DateTime(2020, 1, 4),
    ),
    DocumentsModel(
      name: 'Vacation.jpg',
      path: '',
      type: 'imaage',
      createdAt: DateTime(2020, 1, 5),
    ),
  ];
  String getFileExtension(String fileName) {
    return fileName.split('.').last.toUpperCase();
  }

  List<DocumentsModel> get filteredDocuments {
    final allDocuments = [...sampleDocuments, ...widget.documents];
    allDocuments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final query = searchController.text.toLowerCase();
    final typeFiltered = allDocuments.where((document) {
      if (selectedType == 'all') {
        return true;
      }

      if (selectedType == 'word') {
        return document.name.toLowerCase().endsWith('.doc') ||
            document.name.toLowerCase().endsWith('.docx');
      }

      if (selectedType == 'excel') {
        return document.name.toLowerCase().endsWith('.xls') ||
            document.name.toLowerCase().endsWith('.xlsx');
      }

      if (selectedType == 'powerpoint') {
        return document.name.toLowerCase().endsWith('.ppt') ||
            document.name.toLowerCase().endsWith('.pptx');
      }
      return document.type == selectedType;
    }).toList();

    if (query.isEmpty) {
      return typeFiltered;
    }
    return typeFiltered
        .where((document) => document.name.toLowerCase().contains(query))
        .toList();
  }

  List<DocumentsModel> get recentDocuments {
    final recent = [...widget.documents];
    final query = searchController.text.toLowerCase();

    if (query.isNotEmpty) {
      recent.removeWhere(
        (document) => !document.name.toLowerCase().contains(query),
      );
    }
    if (selectedType == 'word') {
      recent.removeWhere(
        (document) =>
            !document.name.toLowerCase().endsWith('.doc') &&
            !document.name.toLowerCase().endsWith('.docx'),
      );
    } else if (selectedType == 'excel') {
      recent.removeWhere(
        (document) =>
            !document.name.toLowerCase().endsWith('.xls') &&
            !document.name.toLowerCase().endsWith('.xlsx'),
      );
    } else if (selectedType == 'powerpoint') {
      recent.removeWhere(
        (document) =>
            !document.name.toLowerCase().endsWith('.ppt') &&
            !document.name.toLowerCase().endsWith('.pptx'),
      );
    } else if (selectedType != 'all') {
      recent.removeWhere((document) => document.type != selectedType);
    }
    recent.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return recent.take(3).toList();
  }

  void openDocument(DocumentsModel document) {
    if (document.type == 'pdf') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: Text(document.name)),
            body: SfPdfViewer.file(
              File(document.path),
              enableDoubleTapZooming: true,
            ),
          ),
        ),
      );
    } else if (document.type == 'image') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: Text(document.name),
            ),
            body: InteractiveViewer(
              transformationController: imageController,
              minScale: 1.0,
              maxScale: 4.0,
              child: GestureDetector(
                onDoubleTap: () {
                  if (imageController.value.getMaxScaleOnAxis() > 1.0) {
                    imageController.value = Matrix4.identity();
                  } else {
                    imageController.value = Matrix4.identity()..scale(2.5);
                  }
                },
                child: Container(
                  color: Colors.black,
                  width: double.infinity,
                  height: double.infinity,
                  child: Center(
                    child: Image.file(File(document.path), fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      OpenFilex.open(document.path);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        TextField(
          controller: searchController,
          onChanged: (value) {
            setState(() {});
          },
          decoration: InputDecoration(
            hintText: 'Search documents',
            prefixIcon: Icon(Icons.search),
            suffixIcon: searchController.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      searchController.clear();
                      setState(() {});
                    },
                    icon: Icon(Icons.clear),
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: Text(
                  "All",
                  style: TextStyle(
                    color: selectedType == 'all'
                        ? Color(0xFF7046A8)
                        : Color(0xFF55505A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                selected: selectedType == 'all',
                selectedColor: Color(0xFFE8D5F5),
                side: BorderSide(color: Color(0xFF7046A8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (_) {
                  setState(() {
                    selectedType = 'all';
                  });
                },
              ),
              SizedBox(width: 8),
              FilterChip(
                label: Text(
                  "PDF",
                  style: TextStyle(
                    color: selectedType == 'all'
                        ? Color(0xFF7046A8)
                        : Color(0xFF55505A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                selected: selectedType == 'pdf',
                selectedColor: Color(0xFFE8D5F5),
                side: BorderSide(color: Color(0xFF7046A8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (_) {
                  setState(() {
                    selectedType = 'pdf';
                  });
                },
              ),
              SizedBox(width: 8),
              FilterChip(
                label: Text(
                  "Word",
                  style: TextStyle(
                    color: selectedType == 'all'
                        ? Color(0xFF7046A8)
                        : Color(0xFF55505A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                selected: selectedType == 'word',
                selectedColor: Color(0xFFE8D5F5),
                side: BorderSide(color: Color(0xFF7046A8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (_) {
                  setState(() {
                    selectedType = 'word';
                  });
                },
              ),
              SizedBox(width: 8),
              FilterChip(
                label: Text(
                  "Excel",
                  style: TextStyle(
                    color: selectedType == 'all'
                        ? Color(0xFF7046A8)
                        : Color(0xFF55505A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                selected: selectedType == 'excel',
                selectedColor: Color(0xFFE8D5F5),
                side: BorderSide(color: Color(0xFF7046A8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (_) {
                  setState(() {
                    selectedType = 'excel';
                  });
                },
              ),
              SizedBox(width: 8),
              FilterChip(
                label: Text(
                  "PowerPoint",
                  style: TextStyle(
                    color: selectedType == 'all'
                        ? Color(0xFF7046A8)
                        : Color(0xFF55505A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                selected: selectedType == 'powerpoint',
                selectedColor: Color(0xFFE8D5F5),
                side: BorderSide(color: Color(0xFF7046A8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (_) {
                  setState(() {
                    selectedType = 'powerpoint';
                  });
                },
              ),
              SizedBox(width: 8),
              FilterChip(
                label: Text(
                  "Images",
                  style: TextStyle(
                    color: selectedType == 'all'
                        ? Color(0xFF7046A8)
                        : Color(0xFF55505A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                selected: selectedType == 'image',
                selectedColor: Color(0xFFE8D5F5),
                side: BorderSide(color: Color(0xFF7046A8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (_) {
                  setState(() {
                    selectedType = 'image';
                  });
                },
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        if (recentDocuments.isNotEmpty) ...[],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Recently Added",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              "New",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        SizedBox(height: 12),
        ...recentDocuments.map(
          (document) => Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              onTap: () {
                openDocument(document);
              },
              leading: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(0xFFF1E7FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  document.type == 'pdf'
                      ? Icons.picture_as_pdf_outlined
                      : document.type == 'office'
                      ? Icons.description_outlined
                      : Icons.image_outlined,
                  color: document.type == 'pdf'
                      ? Color(0xFF7046A8)
                      : document.type == "office"
                      ? Color(0xFF3D8B5F)
                      : Color(0xFF4B8799),
                  size: 26,
                ),
              ),
              title: Text(
                document.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D2435),
                ),
              ),
              subtitle: Text(
                getFileExtension(document.name),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B6570),
                  letterSpacing: 0.5,
                ),
              ),
              trailing: widget.documents.contains(document)
                  ? PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == "delete") {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text("Delete Document"),
                                content: Text(
                                  "Are you sure you want to delete this document?",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      widget.onDocumentDelete(document);
                                    },
                                    child: Text("Delete"),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: "delete", child: Text("Delete")),
                      ],
                    )
                  : null,
            ),
          ),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "All Documents",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              "${filteredDocuments.length} ${filteredDocuments.length == 1 ? 'file' : 'files'}",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        SizedBox(height: 12),
        if (filteredDocuments.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                "No Documents found",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B6570),
                ),
              ),
            ),
          ),
        ...filteredDocuments.map(
          (document) => Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: EdgeInsets.only(bottom: 10),
            child: ListTile(
              onTap: () {
                openDocument(document);
              },
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              leading: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(0xFFF1E7FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  size: 26,
                  document.type == 'pdf'
                      ? Icons.picture_as_pdf_outlined
                      : document.type == "office"
                      ? Icons.description_outlined
                      : Icons.image_outlined,
                  color: document.type == 'pdf'
                      ? Color(0xFF7046A8)
                      : document.type == "office"
                      ? Color(0xFF3D8B5F)
                      : Color(0xFF4B8799),
                ),
              ),
              title: Text(
                document.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D2435),
                ),
              ),
              subtitle: Text(
                getFileExtension(document.name),
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B6570),
                  letterSpacing: 0.5,
                ),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == "delete") {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text("Delete Document"),
                          content: Text(
                            "Are you sure you want to delete this document?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onDocumentDelete(document);
                              },
                              child: Text("Delete"),
                            ),
                          ],
                        );
                      },
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: "delete", child: Text("delete")),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
