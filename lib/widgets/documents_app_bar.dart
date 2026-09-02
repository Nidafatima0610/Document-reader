import 'package:flutter/material.dart';

class DocumentsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DocumentsAppBar({super.key});

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
  Widget build(BuildContext context) {
    return AppBar(
      title: Text("Documents"),
      actions: [
        IconButton(onPressed: () {}, icon: Icon(Icons.search)),
        IconButton(onPressed: () {}, icon: Icon(Icons.more_vert)),
      ],
    );
  }
}
