import 'package:all_documents_reader/views/documents_view.dart';
import 'package:all_documents_reader/views/settings_view.dart';
import 'package:all_documents_reader/widgets/home_app_bar.dart';
import 'package:all_documents_reader/widgets/home_body.dart';
import 'package:all_documents_reader/widgets/home_bottom_navigation.dart';
import 'package:flutter/material.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [HomeView(), DocumentsView(), SettingsView()];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HomeAppBar(),
      body: _selectedIndex == 0
        ? HomeBody() : _selectedIndex == 1 ? DocumentsView() : SettingsView(),
      bottomNavigationBar: HomeBottomNavigation(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
