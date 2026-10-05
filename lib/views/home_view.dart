import 'package:all_documents_reader/views/ai_document_assistant_view.dart';
import 'package:all_documents_reader/views/career_view.dart';
import 'package:all_documents_reader/views/documents_view.dart';
import 'package:all_documents_reader/views/favorites_view.dart';
import 'package:all_documents_reader/views/ocr_workspace_view.dart';
import 'package:all_documents_reader/views/recent_documents_view.dart';
import 'package:all_documents_reader/views/settings_view.dart';
import 'package:all_documents_reader/views/smart_scanner_view.dart';
import 'package:all_documents_reader/views/tools_view.dart';
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

  void _navigateToDocuments([String? category]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentsView(initialCategory: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          _selectedIndex = 0;
        });
      },
      child: Scaffold(
        appBar: _selectedIndex == 0
            ? HomeAppBar(
                onSearchPressed: () => _navigateToDocuments(),
                onSettingsPressed: () {
                  setState(() {
                    _selectedIndex = 5;
                  });
                },
              )
            : null,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            // Index 0: Home
            HomeBody(
              onSeeAllRecent: () {
                setState(() {
                  _selectedIndex = 1;
                });
              },
              onSearchPressed: () => _navigateToDocuments(),
              onCategorySelected: (category) => _navigateToDocuments(category),
              onOpenScanner: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SmartScannerView(),
                  ),
                );
              },
              onOpenOcr: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OcrWorkspaceView(),
                  ),
                );
              },
              onOpenAiAssistant: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AiDocumentAssistantView(),
                  ),
                );
              },
              onOpenTools: () {
                setState(() {
                  _selectedIndex = 2;
                });
              },
              onOpenFavorites: () {
                setState(() {
                  _selectedIndex = 3;
                });
              },
            ),

            // Index 1: Recent
            RecentDocumentsView(
              onBrowseDocuments: () => _navigateToDocuments(),
            ),

            // Index 2: Tools
            const ToolsView(),

            // Index 3: Favorites
            FavoritesView(
              onBrowseDocuments: () => _navigateToDocuments(),
            ),

            // Index 4: Career
            const CareerView(),

            // Index 5: Settings
            const SettingsView(),
          ],
        ),
        bottomNavigationBar: HomeBottomNavigation(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        ),
      ),
    );
  }
}
