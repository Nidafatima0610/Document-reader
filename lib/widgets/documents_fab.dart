import 'package:all_documents_reader/models/documents_model.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class DocumentsFab extends StatelessWidget {
  final Function(DocumentsModel) onDocumentPicked;
  const DocumentsFab({super.key, required this.onDocumentPicked});

  String getDocumentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    if (extension == 'pdf') {
      return 'pdf';
    }

    if (['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'].contains(extension)) {
      return 'office';
    }
    return 'image';
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      elevation: 4,
      backgroundColor: Color(0xFF7046A8),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadiusGeometry.circular(16),
      ),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.vertical(
              top: Radius.circular(24),
            ),
          ),
          builder: (context) {
            return SizedBox(
              height: 320,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Add Document",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    ListTile(
                      onTap: () async {
                        List<PlatformFile> files = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: [
                            "pdf",
                            "doc",
                            "docx",
                            "xls",
                            "xlsx",
                            "ppt",
                            "pptx",
                          ],
                        );
                        if (files.isEmpty) {
                          return;
                        }
                        final document = DocumentsModel(
                          name: files.first.name,
                          path: files.first.path ?? '',
                          type: getDocumentType(files.first.name),
                          createdAt: DateTime.now(),
                        );
                        onDocumentPicked(document);
                        Navigator.pop(context);
                      },
                      leading: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color(0xFFF1E7FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.picture_as_pdf_outlined,
                          color: Color(0xFF7046A8),
                        ),
                      ),
                      title: Text(
                        "PDF Document",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D2435),
                        ),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios),
                    ),
                    SizedBox(height: 8),
                    ListTile(
                      onTap: () async {
                        List<PlatformFile> files = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: [
                            "doc",
                            "docx",
                            "xls",
                            "xlsx",
                            "ppt",
                            "pptx",
                          ],
                        );
                        if (files.isEmpty) {
                          return;
                        }
                        final document = DocumentsModel(
                          name: files.first.name,
                          path: files.first.path ?? '',
                          type: getDocumentType(files.first.name),
                          createdAt: DateTime.now(),
                        );
                        onDocumentPicked(document);
                        Navigator.pop(context);
                      },
                      leading: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color(0xFFE5F3EA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.table_chart_outlined,
                          color: Color(0xFF3D8B5F),
                        ),
                      ),
                      title: Text(
                        "Office Document",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D2435),
                        ),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios),
                    ),
                    SizedBox(height: 8),
                    ListTile(
                      onTap: () async {
                        List<PlatformFile> files = await FilePicker.pickFiles(
                          type: FileType.image,
                        );
                        if (files.isEmpty) {
                          return;
                        }
                        final document = DocumentsModel(
                          name: files.first.name,
                          path: files.first.path ?? '',
                          type: getDocumentType(files.first.name),
                          createdAt: DateTime.now(),
                        );
                        onDocumentPicked(document);
                        Navigator.pop(context);
                      },
                      leading: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color(0xFFE6F0F4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          color: Color(0xFF4B8799),
                        ),
                      ),
                      title: Text(
                        "Image",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D2435),
                        ),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      child: Icon(Icons.add),
    );
  }
}
