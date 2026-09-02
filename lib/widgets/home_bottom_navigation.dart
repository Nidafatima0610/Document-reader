import 'package:flutter/material.dart';

class HomeBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  const HomeBottomNavigation({super.key,required this.onDestinationSelected,required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          label: "Home",
          selectedIcon: Icon(Icons.home),
        ),
        NavigationDestination(
          icon: Icon(Icons.folder_outlined),
          label: "Documents",
          selectedIcon: Icon(Icons.folder),
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          label: "Settings",
          selectedIcon: Icon(Icons.settings),
        ),
      ],
    );
  }
}
