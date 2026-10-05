import 'package:flutter/material.dart';

class HomeBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const HomeBottomNavigation({
    super.key,
    required this.onDestinationSelected,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: 68,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined, size: 22),
          label: "Home",
          selectedIcon: Icon(Icons.home_rounded, size: 22),
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined, size: 22),
          label: "Recent",
          selectedIcon: Icon(Icons.history_rounded, size: 22),
        ),
        NavigationDestination(
          icon: Icon(Icons.construction_outlined, size: 22),
          label: "Tools",
          selectedIcon: Icon(Icons.construction_rounded, size: 22),
        ),
        NavigationDestination(
          icon: Icon(Icons.star_outline_rounded, size: 22),
          label: "Favorites",
          selectedIcon: Icon(Icons.star_rounded, size: 22),
        ),
        NavigationDestination(
          icon: Icon(Icons.work_outline_rounded, size: 22),
          label: "Career",
          selectedIcon: Icon(Icons.work_rounded, size: 22),
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined, size: 22),
          label: "Settings",
          selectedIcon: Icon(Icons.settings_rounded, size: 22),
        ),
      ],
    );
  }
}
