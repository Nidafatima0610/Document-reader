import 'package:flutter/material.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key});

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
  Widget build(BuildContext context) {
    return AppBar(
      title: Text("All Documents Reader"),
      leading: Icon(Icons.description_outlined),
      actions: [
        IconButton(onPressed: () {}, icon: Icon(Icons.search)),
        IconButton(onPressed: () {}, icon: Icon(Icons.settings_outlined)),
      ],
    );
  }
}
