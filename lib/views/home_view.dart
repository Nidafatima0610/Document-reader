import 'package:all_documents_reader/services/premium_service.dart';
import 'package:all_documents_reader/views/ai_document_assistant_view.dart';
import 'package:all_documents_reader/views/documents_view.dart';
import 'package:all_documents_reader/views/favorites_view.dart';
import 'package:all_documents_reader/views/ocr_workspace_view.dart';
import 'package:all_documents_reader/views/premium_view.dart';
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
  String? _documentsCategory;

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
              onSearchPressed: () {
                setState(() {
                  _selectedIndex = 1;
                });
              },
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
          HomeBody(
            onSeeAllRecent: () {
              setState(() {
                _selectedIndex = 3;
              });
            },
            onSearchPressed: () {
              setState(() {
                _selectedIndex = 1;
              });
            },
            onCategorySelected: (category) {
              setState(() {
                _documentsCategory = category;
                _selectedIndex = 1;
              });
            },
            onOpenScanner: () {
              if (!PremiumService.instance.isPremium) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PremiumView(
                      highlightBenefitTitle: 'Smart Scanner',
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SmartScannerView(),
                  ),
                );
              }
            },
            onOpenOcr: () {
              if (!PremiumService.instance.isPremium) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PremiumView(
                      highlightBenefitTitle: 'OCR Workspace',
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OcrWorkspaceView(),
                  ),
                );
              }
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
                _selectedIndex = 4;
              });
            },
          ),
          DocumentsView(
            key: ValueKey(_documentsCategory ?? 'all'),
            initialCategory: _documentsCategory,
          ),
          const ToolsView(),
          RecentDocumentsView(
            onBrowseDocuments: () {
              setState(() {
                _selectedIndex = 1;
              });
            },
          ),
          FavoritesView(
            onBrowseDocuments: () {
              setState(() {
                _selectedIndex = 1;
              });
            },
          ),
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
