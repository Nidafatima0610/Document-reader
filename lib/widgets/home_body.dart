import 'package:flutter/material.dart';

class HomeBody extends StatelessWidget {
  const HomeBody({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        SizedBox(height: 25),
        TextField(
          decoration: InputDecoration(
            hintText: "Search Documents",
            prefixIcon: Icon(Icons.search),
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        SizedBox(height: 24),
        Text(
          "Recent Documents",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D2435),
          ),
        ),
        SizedBox(height: 12),
        Card(
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            leading: Icon(
              Icons.picture_as_pdf_outlined,
              size: 30,
              color: Color(0xFF7046A8),
            ),
            title: Text(
              "Sample Document.pdf",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            subtitle: Text("PDF.2.4 MB", style: TextStyle(fontSize: 12)),
          ),
        ),
        SizedBox(height: 8),
        Card(
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            leading: Icon(
              Icons.table_chart_outlined,
              size: 30,
              color: Color(0xFF3D8B5F),
            ),
            title: Text(
              "Budget.xlsx",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            subtitle: Text("Excel.1.8 MB", style: TextStyle(fontSize: 12)),
          ),
        ),
        SizedBox(height: 8),
        Card(
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            leading: Icon(
              Icons.description_outlined,
              size: 30,
              color: Color(0xFF3D8B5F),
            ),
            title: Text(
              "Assignment.docx",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            subtitle: Text("Word.850 KB", style: TextStyle(fontSize: 12)),
          ),
        ),
        SizedBox(height: 24),
        Text(
          "Categories",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D2435),
          ),
        ),
        SizedBox(height: 12),
        GridView.count(
          childAspectRatio: 1.15,
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          children: [
            Card(
              color: Color(0xFFF1E7FA),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 32,
                      color: Color(0xFF7046A8),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "PDF",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2435),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              color: Color(0xFFE8EEF9),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 32,
                      color: Color(0xFF3F6FA8),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Word",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2435),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              color: Color(0xFFE5F3EA),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.table_chart_outlined,
                      size: 32,
                      color: Color(0xFF3D8B5F),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Excel",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2435),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              color: Color(0xFFF9E9DF),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.slideshow_outlined,
                      size: 32,
                      color: Color(0xFFC7653C),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "PowerPoint",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2435),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              color: Color(0xFFF4EBD8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.text_snippet_outlined,
                      size: 32,
                      color: Color(0xFF8A6D3B),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Text",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2435),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              color: Color(0xFFE6F0F4),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 32,
                      color: Color(0xFF4B8799),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Images",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2435),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
