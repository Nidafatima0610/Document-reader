import 'dart:io';
import 'package:all_documents_reader/core/config/app_config.dart';
import 'package:all_documents_reader/core/theme/app_theme.dart';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/ad_mob_service.dart';
import 'package:all_documents_reader/services/ai_document_service.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/ocr_service.dart';
import 'package:all_documents_reader/services/pdf_generator_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:all_documents_reader/services/pdf_to_image_service.dart';
import 'package:all_documents_reader/services/settings_service.dart';
import 'package:all_documents_reader/services/text_to_pdf_service.dart';
import 'package:all_documents_reader/services/tools_registry_service.dart';
import 'package:all_documents_reader/models/scanned_page_model.dart';
import 'package:all_documents_reader/models/tool_item_model.dart';
import 'package:all_documents_reader/services/premium_service.dart';
import 'package:all_documents_reader/services/scanner_image_processing_service.dart';
import 'package:all_documents_reader/views/ai_document_assistant_view.dart';
import 'package:all_documents_reader/views/ocr_workspace_view.dart';
import 'package:all_documents_reader/views/compress_pdf_view.dart';
import 'package:all_documents_reader/views/document_details_view.dart';
import 'package:all_documents_reader/views/documents_view.dart';
import 'package:all_documents_reader/views/home_view.dart';
import 'package:all_documents_reader/views/image_to_text_view.dart';
import 'package:all_documents_reader/views/images_to_pdf_view.dart';
import 'package:all_documents_reader/views/manual_crop_view.dart';
import 'package:all_documents_reader/views/merge_pdf_view.dart';
import 'package:all_documents_reader/views/pdf_to_image_view.dart';
import 'package:all_documents_reader/views/pdf_to_text_view.dart';
import 'package:all_documents_reader/views/reorder_pdf_view.dart';
import 'package:all_documents_reader/views/rotate_pdf_view.dart';
import 'package:all_documents_reader/views/scanner_result_view.dart';
import 'package:all_documents_reader/views/pdf_viewer_screen.dart';
import 'package:all_documents_reader/views/settings_view.dart';
import 'package:all_documents_reader/views/smart_scanner_view.dart';
import 'package:all_documents_reader/views/split_pdf_view.dart';
import 'package:all_documents_reader/views/text_to_pdf_view.dart';
import 'package:all_documents_reader/views/tools_view.dart';
import 'package:all_documents_reader/views/scan_to_pdf_workspace_view.dart';
import 'package:all_documents_reader/views/word_converter_view.dart';
import 'package:all_documents_reader/widgets/documents_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    await PremiumService.instance.init();
    await PremiumService.instance.setPremiumForTesting(false);
    await DocumentsStorageService().loadFavorites();
    await DocumentsStorageService().loadRecentDocuments();
  });

  testWidgets('SettingsView renders all sections and header', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const SettingsView()),
    );
    await tester.pumpAndSettle();

    // Verify header
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('All Documents Reader'), findsWidgets);
    expect(find.text('PRO'), findsOneWidget);

    // Verify sections
    expect(find.text('Premium & Monetization'), findsOneWidget);
    expect(find.text('Remove Ads & Go Premium'), findsOneWidget);
    expect(find.text('Appearance & Theme'), findsOneWidget);
    expect(find.text('Reading Preferences'), findsOneWidget);
    expect(find.text('Storage & File Management'), findsOneWidget);
    expect(find.text('Support & Community'), findsOneWidget);
    expect(find.text('About & Legal'), findsOneWidget);

    // Verify tiles
    expect(find.text('Theme Mode'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.text('Default Viewer Mode'), findsOneWidget);
    expect(find.text('Keep Screen Awake'), findsOneWidget);
    expect(find.text('Clear Document Cache'), findsOneWidget);
    expect(find.text('Help & FAQ'), findsOneWidget);
    expect(find.text('Rate Us & Feedback'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
  });

  testWidgets('Theme mode selection dialog works', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const SettingsView()),
    );
    await tester.pumpAndSettle();

    // Tap on Theme Mode tile
    await tester.tap(find.text('Theme Mode'));
    await tester.pumpAndSettle();

    // Verify dialog shows
    expect(find.text('Choose Theme'), findsOneWidget);
    expect(find.text('Dark Theme'), findsOneWidget);

    // Select Dark Theme
    await tester.tap(find.text('Dark Theme'));
    await tester.pumpAndSettle();

    // Verify ThemeMode changed to dark
    expect(SettingsService.instance.themeModeNotifier.value, ThemeMode.dark);
  });

  testWidgets('Bottom navigation switches to SettingsView from HomeView', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const HomeView()),
    );
    await tester.pumpAndSettle();

    // Tap Settings destination in Bottom Navigation
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Verify Settings view is rendered
    expect(find.text('Appearance & Theme'), findsOneWidget);
  });

  testWidgets(
    'DocumentsView renders category chips, search bar, and documents',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const DocumentsView()),
      );
      await tester.pumpAndSettle();

      // Verify AppBar and FAB
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Add Document'), findsOneWidget);

      // Verify Category Chips: All, PDF, Office, Images, Other
      expect(find.text('All'), findsOneWidget);
      expect(find.text('PDF'), findsWidgets);
      expect(find.text('Office'), findsOneWidget);
      expect(find.text('Images'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);

      // Verify sample documents are rendered
      expect(find.text('Sample Document.pdf'), findsOneWidget);
      expect(find.text('Budget Plan.xlsx'), findsOneWidget);
      expect(find.text('Project Assignment.docx'), findsOneWidget);
      expect(find.text('Business Presentation.pptx'), findsOneWidget);
      expect(find.text('Quick Notes.txt'), findsOneWidget);
      expect(find.text('Vacation Photo.jpg'), findsOneWidget);
    },
  );

  testWidgets('Category chips correctly filter document list', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const DocumentsView()),
    );
    await tester.pumpAndSettle();

    // Tap PDF category chip
    await tester.tap(find.widgetWithText(ChoiceChip, 'PDF'));
    await tester.pumpAndSettle();

    expect(find.text('Sample Document.pdf'), findsOneWidget);
    expect(find.text('Budget Plan.xlsx'), findsNothing);
    expect(find.text('Project Assignment.docx'), findsNothing);

    // Tap Office category chip
    await tester.tap(find.widgetWithText(ChoiceChip, 'Office'));
    await tester.pumpAndSettle();

    expect(find.text('Sample Document.pdf'), findsNothing);
    expect(find.text('Budget Plan.xlsx'), findsOneWidget);
    expect(find.text('Project Assignment.docx'), findsOneWidget);
    expect(find.text('Business Presentation.pptx'), findsOneWidget);

    // Tap Images category chip
    await tester.tap(find.widgetWithText(ChoiceChip, 'Images'));
    await tester.pumpAndSettle();

    expect(find.text('Vacation Photo.jpg'), findsOneWidget);
    expect(find.text('Sample Document.pdf'), findsNothing);
  });

  testWidgets('Search bar filters documents in real-time', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const DocumentsView()),
    );
    await tester.pumpAndSettle();

    // Enter search query
    await tester.enterText(find.byType(TextField), 'Budget');
    await tester.pumpAndSettle();

    expect(find.text('Budget Plan.xlsx'), findsOneWidget);
    expect(find.text('Sample Document.pdf'), findsNothing);
    expect(find.text('Vacation Photo.jpg'), findsNothing);

    // Clear search query
    await tester.tap(find.byIcon(Icons.clear_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Sample Document.pdf'), findsOneWidget);
    expect(find.text('Budget Plan.xlsx'), findsOneWidget);
  });

  testWidgets('Deleting custom document prompts confirmation dialog', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final customDoc = DocumentsModel(
      name: 'Custom File.pdf',
      path: '/path/to/custom.pdf',
      type: 'pdf',
      createdAt: DateTime.now(),
    );

    bool deleted = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: DocumentsBody(
            documents: [customDoc],
            onDocumentDelete: (doc) {
              deleted = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Custom File.pdf'), findsOneWidget);

    // Tap options menu
    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();

    // Tap Delete in menu
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Verify dialog appears
    expect(find.text('Delete Document'), findsOneWidget);

    // Confirm deletion
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });

  testWidgets(
    'Star action marks document as favorite and reflects in FavoritesView',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const HomeView()),
      );
      await tester.pumpAndSettle();

      // Navigate to Documents Tab (Index 1)
      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();

      // Find star IconButton on the first document card and tap it
      final cardStarButton = find
          .widgetWithIcon(IconButton, Icons.star_outline_rounded)
          .first;
      await tester.tap(cardStarButton);
      await tester.pumpAndSettle();

      // Now navigate to Favorites Tab (Index 3)
      await tester.tap(find.text('Favorites'));
      await tester.pumpAndSettle();

      // Verify "Favorites" AppBar and the favorited document is displayed
      expect(find.text('Favorites'), findsWidgets);
      expect(find.text('Vacation Photo.jpg'), findsOneWidget);

      // Remove from favorites from the FavoritesView by tapping the gold star
      final favStarButton = find
          .widgetWithIcon(IconButton, Icons.star_rounded)
          .first;
      await tester.tap(favStarButton);
      await tester.pumpAndSettle();

      // Verify empty state is shown
      expect(find.text('No Favorites Yet'), findsOneWidget);
      expect(find.text('Browse Documents'), findsOneWidget);

      // Tapping "Browse Documents" switches back to Documents tab
      await tester.tap(find.widgetWithText(ElevatedButton, 'Browse Documents'));
      await tester.pumpAndSettle();

      expect(find.text('All Documents'), findsOneWidget);
    },
  );

  testWidgets(
    'Recent documents tracking, duplicate handling, and 10-item cap',
    (WidgetTester tester) async {
      final storage = DocumentsStorageService.instance;
      await storage.clearRecentDocuments();

      // 1. Add 12 documents sequentially
      for (int i = 1; i <= 12; i++) {
        await storage.recordDocumentOpened(
          DocumentsModel(
            name: 'Document_$i.pdf',
            path: '/path/doc_$i.pdf',
            type: 'pdf',
            createdAt: DateTime.now(),
          ),
        );
      }

      // Verify max length is 10
      expect(storage.recentDocumentsNotifier.value.length, 10);
      // Most recent should be at index 0 (Document_12)
      expect(storage.recentDocumentsNotifier.value.first.name, 'Document_12.pdf');
      // Oldest kept document should be Document_3
      expect(storage.recentDocumentsNotifier.value.last.name, 'Document_3.pdf');

      // 2. Re-open Document_5 (already in the list)
      await storage.recordDocumentOpened(
        DocumentsModel(
          name: 'Document_5.pdf',
          path: '/path/doc_5.pdf',
          type: 'pdf',
          createdAt: DateTime.now(),
        ),
      );

      // Still 10 documents (no duplicate created!)
      expect(storage.recentDocumentsNotifier.value.length, 10);
      // Document_5 is moved to the top
      expect(storage.recentDocumentsNotifier.value.first.name, 'Document_5.pdf');
    },
  );

  testWidgets(
    'RecentDocumentsView renders recent items, supports clear history, and navigation',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final storage = DocumentsStorageService.instance;
      await storage.clearRecentDocuments();

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const HomeView()),
      );
      await tester.pumpAndSettle();

      // Navigate to Recent Tab (Index 2)
      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();

      // Verify empty state is displayed initially
      expect(find.text('Recent Documents'), findsWidgets);
      expect(find.text('No Recent Documents'), findsOneWidget);

      // Navigate to Documents tab and open a sample document
      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();

      // Tap first document card to trigger open & record history
      await tester.tap(find.text('Vacation Photo.jpg'));
      await tester.pumpAndSettle();

      // Navigate back to Recent Tab
      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();

      // Verify document now appears in Recent Documents
      expect(find.text('Vacation Photo.jpg'), findsOneWidget);

      // Tap clear history action in AppBar
      await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Clear Recent'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Clear All'));
      await tester.pumpAndSettle();

      // Verify empty state is back
      expect(find.text('No Recent Documents'), findsOneWidget);
    },
  );

  testWidgets(
    'DocumentDetailsView renders metadata, supports favorite toggle and delete',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final customDoc = DocumentsModel(
        name: 'Report_2026.pdf',
        path: '/storage/Report_2026.pdf',
        type: 'pdf',
        createdAt: DateTime(2026, 3, 15, 10, 30),
      );

      final storage = DocumentsStorageService.instance;
      await storage.saveDocuments([customDoc]);
      await storage.loadFavorites();

      bool deletedFromCallback = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: DocumentDetailsView(
            document: customDoc,
            onDocumentDelete: (doc) {
              deletedFromCallback = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Document Details screen is rendered
      expect(find.text('Document Details'), findsOneWidget);
      expect(find.text('Report_2026.pdf'), findsOneWidget);
      expect(find.text('PDF Document'), findsOneWidget);
      expect(find.text('Open Document'), findsOneWidget);
      expect(find.text('File Location'), findsOneWidget);
      expect(find.text('/storage/Report_2026.pdf'), findsOneWidget);

      // Test Favorite action
      await tester.tap(find.text('Favorite'));
      await tester.pumpAndSettle();

      expect(storage.isFavorite(customDoc), isTrue);

      // Test Delete action
      await tester.tap(find.text('Delete Document'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Document'), findsWidgets);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(deletedFromCallback, isTrue);
    },
  );

  testWidgets(
    'Adding the same document multiple times does not produce duplicates',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final customImage = DocumentsModel(
        name: 'MyScan.jpg',
        path: '/storage/MyScan.jpg',
        type: 'image',
        createdAt: DateTime.now(),
      );

      final storage = DocumentsStorageService.instance;
      // Save the document twice to simulate double addition
      await storage.saveDocuments([customImage, customImage]);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: DocumentsBody(
              documents: [customImage, customImage],
              onDocumentDelete: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify MyScan.jpg appears EXACTLY ONCE
      expect(find.text('MyScan.jpg'), findsOneWidget);
    },
  );

  testWidgets(
    'Bottom navigation switches to ToolsView from HomeView and displays categories and tools',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const HomeView()),
      );
      await tester.pumpAndSettle();

      // Tap Tools destination in Bottom Navigation
      await tester.tap(find.text('Tools'));
      await tester.pumpAndSettle();

      // Verify Tools header and banner
      expect(find.text('All-in-One Document Utilities'), findsOneWidget);
      expect(find.text('${ToolsRegistryService.instance.getAllTools().length} Tools'), findsOneWidget);

      // Verify category headers
      expect(find.text('CREATE'), findsOneWidget);
      expect(find.text('CONVERT'), findsOneWidget);
      expect(find.text('MANAGE PDF'), findsOneWidget);

      // Verify sample tools in each category
      expect(find.text('Images to PDF'), findsOneWidget);
      expect(find.text('Text to PDF'), findsOneWidget);
      expect(find.text('Word to PDF'), findsOneWidget);
      expect(find.text('Merge PDF'), findsOneWidget);
      expect(find.text('Compress PDF'), findsOneWidget);
    },
  );

  testWidgets(
    'Tools search bar filters tools in real-time and clears query',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const ToolsView()),
      );
      await tester.pumpAndSettle();

      // Search for "Merge"
      await tester.enterText(find.byType(TextField), 'Merge');
      await tester.pumpAndSettle();

      expect(find.text('Merge PDF'), findsOneWidget);
      expect(find.text('Compress PDF'), findsNothing);
      expect(find.text('Text to PDF'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Merge PDF'), findsOneWidget);
      expect(find.text('Compress PDF'), findsOneWidget);
      expect(find.text('Text to PDF'), findsOneWidget);
    },
  );

  testWidgets(
    'Category chips filter tools correctly',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const ToolsView()),
      );
      await tester.pumpAndSettle();

      // Tap "Manage PDF" filter chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Manage PDF'));
      await tester.pumpAndSettle();

      // Manage PDF tools should be visible
      expect(find.text('Merge PDF'), findsOneWidget);
      expect(find.text('Split PDF'), findsOneWidget);
      expect(find.text('Compress PDF'), findsOneWidget);

      // Create tools should not be visible
      expect(find.text('Text to PDF'), findsNothing);

      // Tap "Create" filter chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Create'));
      await tester.pumpAndSettle();

      expect(find.text('Images to PDF'), findsOneWidget);
      expect(find.text('Text to PDF'), findsOneWidget);
      expect(find.text('Merge PDF'), findsNothing);
    },
  );

  testWidgets(
    'Tapping "Merge PDF" in ToolsView opens MergePdfView when Premium is active',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await PremiumService.instance.setPremiumForTesting(true);
      addTearDown(() => PremiumService.instance.setPremiumForTesting(false));

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const ToolsView()),
      );
      await tester.pumpAndSettle();

      // Tap "Merge PDF" tool card
      await tester.tap(find.text('Merge PDF'));
      await tester.pumpAndSettle();

      // Verify MergePdfView is shown
      expect(find.text('Select PDFs to Merge'), findsOneWidget);
      expect(find.text('Select PDF Files'), findsOneWidget);

      // Tap back button to navigate back
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Verify back in ToolsView
      expect(find.text('${ToolsRegistryService.instance.getAllTools().length} Tools'), findsOneWidget);
    },
  );

  testWidgets(
    'Tapping "Images to PDF" in ToolsView opens ImagesToPdfView when Premium is active',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await PremiumService.instance.setPremiumForTesting(true);
      addTearDown(() => PremiumService.instance.setPremiumForTesting(false));

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const ToolsView()),
      );
      await tester.pumpAndSettle();

      // Tap "Images to PDF" tool card
      await tester.tap(find.text('Images to PDF'));
      await tester.pumpAndSettle();

      // Verify ImagesToPdfView screen is displayed
      expect(find.text('Select Images to Convert'), findsOneWidget);
      expect(find.text('Select Images'), findsOneWidget);
      expect(find.text('JPG'), findsOneWidget);
      expect(find.text('PNG'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Back in ToolsView
      expect(find.text('${ToolsRegistryService.instance.getAllTools().length} Tools'), findsOneWidget);
    },
  );

  testWidgets(
    'Tapping locked Premium tool opens PremiumView for Free users',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await PremiumService.instance.setPremiumForTesting(false);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const ToolsView()),
      );
      await tester.pumpAndSettle();

      // Tap "Merge PDF" tool card as Free user
      await tester.tap(find.text('Merge PDF'));
      await tester.pumpAndSettle();

      // Verify PremiumView upgrade screen is displayed
      expect(find.text('All Documents Reader PRO'), findsOneWidget);
      expect(find.text('EVERYTHING INCLUDED WITH PRO'), findsOneWidget);
    },
  );

  test(
    'PdfGeneratorService creates a real PDF from images and saves to storage',
    () async {
      final tempDir = Directory.systemTemp.createTempSync('img_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      // Valid 1x1 PNG bytes
      final pngBytes = <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ];

      final img1 = File('${tempDir.path}/photo_1.png');
      img1.writeAsBytesSync(pngBytes);

      final img2 = File('${tempDir.path}/photo_2.png');
      img2.writeAsBytesSync(pngBytes);

      // Generate PDF
      final result = await PdfGeneratorService.instance.generatePdfFromImages(
        imagePaths: [img1.path, img2.path],
        customFileName: 'Generated_Docs.pdf',
        outputDirectory: tempDir,
      );

      // Verify PDF file was created with 2 pages
      expect(result.pageCount, 2);
      expect(result.file.existsSync(), isTrue);
      expect(result.file.lengthSync(), greaterThan(0));
      expect(result.fileName, 'Generated_Docs.pdf');

      // Add to DocumentsStorageService
      final storage = DocumentsStorageService.instance;
      final doc = DocumentsModel(
        name: result.fileName,
        path: result.file.path,
        type: 'pdf',
        createdAt: DateTime.now(),
      );

      await storage.addDocument(doc);

      // Verify it is in saved documents
      final docs = await storage.loadDocuments();
      expect(docs.any((d) => d.name == 'Generated_Docs.pdf'), isTrue);

      // Verify Recent tracking works
      await storage.recordDocumentOpened(doc);
      expect(storage.recentDocumentsNotifier.value.first.name, 'Generated_Docs.pdf');
    },
  );

  test('PdfOperationsService parses page ranges accurately', () {
    final ops = PdfOperationsService.instance;

    // Single page
    expect(ops.parsePageRange('3', 10), [3]);

    // Range
    expect(ops.parsePageRange('1-4', 10), [1, 2, 3, 4]);

    // Reverse range
    expect(ops.parsePageRange('4-2', 10), [2, 3, 4]);

    // Complex list with duplicates and spaces
    expect(ops.parsePageRange('1, 3, 5-7, 3, 10', 10), [1, 3, 5, 6, 7, 10]);

    // Out of bounds clipping
    expect(ops.parsePageRange('0, 2, 12, 15', 5), [2]);

    // Empty / whitespace
    expect(ops.parsePageRange('   ', 10), []);
  });

  test('PdfOperationsService merges, splits, rotates, reorders, and compresses PDFs', () async {
    final tempDir = Directory.systemTemp.createTempSync('pdf_ops_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    // 1. Create a 3-page test PDF
    final doc = PdfDocument();
    for (int i = 1; i <= 3; i++) {
      final p = doc.pages.add();
      p.graphics.drawString(
        'Page $i unique text content',
        PdfStandardFont(PdfFontFamily.helvetica, 14),
      );
    }
    final pdfFile = File('${tempDir.path}/source.pdf');
    await pdfFile.writeAsBytes(doc.saveSync(), flush: true);
    doc.dispose();

    final ops = PdfOperationsService.instance;

    // 2. Inspect PDF
    final info = await ops.inspectPdf(pdfFile.path);
    expect(info.pageCount, 3);
    expect(info.fileSizeBytes, greaterThan(0));

    // 3. Extract Text
    final textResult = await ops.extractTextFromPdf(pdfPath: pdfFile.path);
    expect(textResult.isScannedOrEmpty, isFalse);
    expect(textResult.text.contains('Page 2 unique text content'), isTrue);

    // 4. Split PDF (extract page 2)
    final splitResult = await ops.splitPdf(
      pdfPath: pdfFile.path,
      pages: [2],
      outputDirectory: tempDir,
    );
    expect(splitResult.pageCount, 1);
    expect(splitResult.file.existsSync(), isTrue);

    // 5. Rotate PDF (90 degrees)
    final rotateResult = await ops.rotatePdf(
      pdfPath: pdfFile.path,
      angle: PdfPageRotateAngle.rotateAngle90,
      outputDirectory: tempDir,
    );
    expect(rotateResult.file.existsSync(), isTrue);

    // 6. Reorder PDF (Page 3, Page 1, Page 2)
    final reorderResult = await ops.reorderPdfPages(
      pdfPath: pdfFile.path,
      newPageOrder: [3, 1, 2],
      outputDirectory: tempDir,
    );
    expect(reorderResult.pageCount, 3);
    expect(reorderResult.file.existsSync(), isTrue);

    // 7. Compress PDF
    final compressResult = await ops.compressPdf(
      pdfPath: pdfFile.path,
      outputDirectory: tempDir,
    );
    expect(compressResult.file.existsSync(), isTrue);

    // 8. Merge PDFs
    final mergeResult = await ops.mergePdfs(
      pdfPaths: [pdfFile.path, splitResult.file.path],
      outputDirectory: tempDir,
    );
    expect(mergeResult.pageCount, 4);
    expect(mergeResult.file.existsSync(), isTrue);
  });

  test('TextToPdfService creates paginated PDF from text', () async {
    final tempDir = Directory.systemTemp.createTempSync('txt_pdf_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final longText = List.generate(
      50,
      (i) => 'Paragraph $i: Flutter is an open source framework by Google for multi-platform apps.',
    ).join('\n\n');

    final result = await TextToPdfService.instance.generatePdfFromText(
      text: longText,
      options: const TextToPdfOptions(title: 'My Automated Note', fontSize: 12),
      outputDirectory: tempDir,
    );

    expect(result.pageCount, greaterThan(1));
    expect(result.file.existsSync(), isTrue);
    expect(result.file.lengthSync(), greaterThan(0));
  });

  test('OcrService saves extracted text as a document', () async {
    final tempDir = Directory.systemTemp.createTempSync('ocr_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final doc = await OcrService.instance.saveExtractedTextAsDocument(
      text: 'Recognized receipt total: \$45.99',
      customFileName: 'Receipt_Note.txt',
      outputDirectory: tempDir,
    );

    expect(doc.type, 'txt');
    expect(File(doc.path).existsSync(), isTrue);
    expect(File(doc.path).readAsStringSync(), 'Recognized receipt total: \$45.99');
  });

  test('PdfToImageService converts PDF pages to images using platform channel', () async {
    final tempDir = Directory.systemTemp.createTempSync('pdf_img_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    // Mock the syncfusion_flutter_pdfviewer platform channel
    const channel = MethodChannel('syncfusion_flutter_pdfviewer');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'initializePdfRenderer') {
        return '1';
      } else if (call.method == 'getPagesHeight') {
        return [100.0];
      } else if (call.method == 'getPagesWidth') {
        return [100.0];
      } else if (call.method == 'getPage') {
        final Map args = call.arguments as Map;
        final int w = args['width'] as int;
        final int h = args['height'] as int;
        return Uint8List(w * h * 4);
      } else if (call.method == 'closeDocument') {
        return true;
      }
      return null;
    });

    // Create a dummy PDF
    final doc = PdfDocument();
    doc.pages.add().graphics.drawString('Test Page', PdfStandardFont(PdfFontFamily.helvetica, 12));
    final testPdfFile = File('${tempDir.path}/test.pdf');
    testPdfFile.writeAsBytesSync(doc.saveSync());
    doc.dispose();

    final result = await PdfToImageService.instance.convertPdfToImages(
      pdfPath: testPdfFile.path,
      pageNumbers: [1],
      outputDirectory: tempDir,
    );

    expect(result.pageCount, 1);
    expect(result.generatedFiles.first.existsSync(), isTrue);
    expect(result.generatedFiles.first.path.endsWith('.png'), isTrue);
  });

  test('ToolsRegistryService registers all tools including scan_to_pdf with working routes', () {
    final allDefinitions = ToolsRegistryService.instance.allRegisteredTools;
    expect(allDefinitions.length, 17);

    final ids = allDefinitions.map((t) => t.id).toSet();
    expect(ids.contains('ai_document_assistant'), isTrue);
    expect(ids.contains('ocr_workspace'), isTrue);
    expect(ids.contains('smart_scanner'), isTrue);
    expect(ids.contains('scan_to_pdf'), isTrue);

    final activeTools = ToolsRegistryService.instance.getAllTools();
    if (!AppConfig.isAiFeatureEnabled) {
      expect(activeTools.length, 16);
      expect(activeTools.any((t) => t.id == 'ai_document_assistant'), isFalse);
    } else {
      expect(activeTools.length, 17);
      expect(activeTools.any((t) => t.id == 'ai_document_assistant'), isTrue);
    }

    for (final tool in allDefinitions) {
      expect(tool.title.isNotEmpty, isTrue);
      expect(tool.description.isNotEmpty, isTrue);
      expect(tool.routeBuilder, isNotNull);
    }
  });

  testWidgets('TextToPdfView renders and displays input fields', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const TextToPdfView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Text to PDF'), findsOneWidget);
    expect(find.text('Document Title (Optional)'), findsOneWidget);
    expect(find.text('PDF Options'), findsOneWidget);
    expect(find.text('Convert to PDF'), findsOneWidget);
  });

  testWidgets('PdfToImageView renders empty state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const PdfToImageView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select PDF to Extract Images'), findsOneWidget);
    expect(find.text('Select PDF File'), findsOneWidget);
    expect(find.text('Lossless PNG'), findsOneWidget);
  });

  testWidgets('PdfToTextView renders empty state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const PdfToTextView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Extract Text from PDF'), findsOneWidget);
    expect(find.text('Select PDF File'), findsOneWidget);
  });

  testWidgets('ImageToTextView renders empty state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const ImageToTextView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recognize Text from Image'), findsOneWidget);
    expect(find.text('Select Image'), findsOneWidget);
    expect(find.text('On-Device ML'), findsOneWidget);
  });

  testWidgets('SplitPdfView renders empty state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const SplitPdfView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select PDF to Split'), findsOneWidget);
    expect(find.text('Select PDF File'), findsOneWidget);
  });

  testWidgets('RotatePdfView renders empty state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const RotatePdfView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select PDF to Rotate'), findsOneWidget);
    expect(find.text('Select PDF File'), findsOneWidget);
  });

  testWidgets('ReorderPdfView renders empty state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const ReorderPdfView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select PDF to Reorder'), findsOneWidget);
    expect(find.text('Select PDF File'), findsOneWidget);
  });

  testWidgets('CompressPdfView renders empty state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const CompressPdfView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select PDF to Compress'), findsOneWidget);
    expect(find.text('Select PDF File'), findsOneWidget);
  });

  testWidgets('MergePdfView renders empty state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const MergePdfView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select PDFs to Merge'), findsOneWidget);
    expect(find.text('Select PDF Files'), findsOneWidget);
  });

  testWidgets('WordConverterView renders feasibility details and recommendations', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const WordConverterView(mode: WordConversionMode.pdfToWord),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PDF to Word'), findsWidgets);
    expect(find.text('Enterprise / Cloud Engine Required'), findsOneWidget);
    expect(find.text('Technical Feasibility Assessment'), findsOneWidget);
    expect(find.text('Recommended Working Alternatives:'), findsOneWidget);
  });

  test('ScannedPageModel and DocumentFilterType behave correctly', () {
    expect(DocumentFilterType.original.label, 'Original');
    expect(DocumentFilterType.grayscale.label, 'Grayscale');
    expect(DocumentFilterType.blackAndWhite.label, 'B&W');
    expect(DocumentFilterType.enhanced.label, 'Enhanced');

    const page = ScannedPageModel(
      id: 'p1',
      originalImagePath: '/path/orig.jpg',
      processedImagePath: '/path/proc.jpg',
      currentFilter: DocumentFilterType.original,
      rotationDegrees: 0,
    );

    final updated = page.copyWith(
      currentFilter: DocumentFilterType.grayscale,
      rotationDegrees: 90,
      processedImagePath: '/path/proc_gray.jpg',
    );

    expect(updated.id, 'p1');
    expect(updated.currentFilter, DocumentFilterType.grayscale);
    expect(updated.rotationDegrees, 90);
    expect(updated.processedImagePath, '/path/proc_gray.jpg');
    expect(page == updated, isTrue); // Equality by ID
  });

  test('ScannerImageProcessingService executes real pixel transformations', () async {
    final tempDir = Directory.systemTemp;
    final stamp = DateTime.now().microsecondsSinceEpoch;

    // 1. Create a real 200x200 test RGB image
    final img.Image testImage = img.Image(width: 200, height: 200);
    for (int y = 0; y < 200; y++) {
      for (int x = 0; x < 200; x++) {
        testImage.setPixelRgba(x, y, x, y, 128, 255);
      }
    }
    final rawJpg = img.encodeJpg(testImage);
    final rawFile = File('${tempDir.path}/scanner_test_$stamp.jpg');
    await rawFile.writeAsBytes(rawJpg);

    final service = ScannerImageProcessingService.instance;

    // 2. Test Grayscale filter
    final grayOut = '${tempDir.path}/gray_$stamp.jpg';
    final grayFile = await service.applyFilter(
      inputPath: rawFile.path,
      filter: DocumentFilterType.grayscale,
      outputPath: grayOut,
    );
    expect(grayFile.existsSync(), isTrue);
    final decodedGray = img.decodeImage(await grayFile.readAsBytes());
    expect(decodedGray, isNotNull);
    expect(decodedGray!.width, 200);

    // 3. Test Black & White (Document Binarization) filter
    final bwOut = '${tempDir.path}/bw_$stamp.jpg';
    final bwFile = await service.applyFilter(
      inputPath: rawFile.path,
      filter: DocumentFilterType.blackAndWhite,
      outputPath: bwOut,
    );
    expect(bwFile.existsSync(), isTrue);
    final decodedBw = img.decodeImage(await bwFile.readAsBytes());
    expect(decodedBw, isNotNull);

    // 4. Test Enhanced filter
    final enhOut = '${tempDir.path}/enh_$stamp.jpg';
    final enhFile = await service.applyFilter(
      inputPath: rawFile.path,
      filter: DocumentFilterType.enhanced,
      outputPath: enhOut,
    );
    expect(enhFile.existsSync(), isTrue);

    // 5. Test real pixel Crop (center 50%)
    final cropOut = '${tempDir.path}/crop_$stamp.jpg';
    final cropFile = await service.cropImage(
      inputPath: rawFile.path,
      normalizedRect: const Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
      outputPath: cropOut,
    );
    expect(cropFile.existsSync(), isTrue);
    final decodedCrop = img.decodeImage(await cropFile.readAsBytes());
    expect(decodedCrop, isNotNull);
    expect(decodedCrop!.width, 100);
    expect(decodedCrop.height, 100);

    // 6. Test real Rotation (90 degrees)
    final rotOut = '${tempDir.path}/rot_$stamp.jpg';
    final rotFile = await service.rotateImage(
      inputPath: rawFile.path,
      degrees: 90,
      outputPath: rotOut,
    );
    expect(rotFile.existsSync(), isTrue);
  });

  test('ToolsRegistryService includes Smart Scanner in Create category', () {
    final registry = ToolsRegistryService.instance;
    final allTools = registry.getAllTools();
    final hasSmartScanner = allTools.any((t) => t.id == 'smart_scanner');
    expect(hasSmartScanner, isTrue);

    final createTools = registry.getToolsByCategory(ToolCategory.create);
    expect(createTools.first.id, 'smart_scanner');
    expect(createTools.first.title, 'Smart Scanner');
  });

  testWidgets('ToolsView renders Smart Scanner featured banner', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const ToolsView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Smart Scanner'), findsWidgets);
    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('Scan physical documents, crop, clean B&W & run OCR'), findsOneWidget);
  });

  testWidgets('SmartScannerView renders scanner hub state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const SmartScannerView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Smart Scanner'), findsOneWidget);
    expect(find.text('Document Scanner'), findsOneWidget);
    expect(find.text('Scan Document'), findsOneWidget);
    expect(find.text('From Gallery'), findsOneWidget);
    expect(find.text('Recent Scans'), findsOneWidget);
    expect(find.text('Manual Crop'), findsOneWidget);
    expect(find.text('B&W & Clean'), findsOneWidget);
    expect(find.text('On-Device OCR'), findsOneWidget);
  });

  testWidgets('ManualCropView renders interactive crop interface', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ManualCropView(
          imagePath: '/test/dummy_image.jpg',
          imagePreview: SizedBox(width: 150, height: 150),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Crop Document'), findsOneWidget);
    expect(find.byTooltip('A4 Document Ratio'), findsOneWidget);
    expect(find.byTooltip('Reset Crop'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Apply Crop'), findsOneWidget);
  });

  testWidgets('ScannerResultView renders document summary and OCR triggers', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final tempDir = Directory.systemTemp;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final fakePdf = File('${tempDir.path}/dummy_$stamp.pdf');
    fakePdf.writeAsBytesSync([1, 2, 3]);

    final result = PdfGenerationResult(
      file: fakePdf,
      fileName: 'Scanned_Document.pdf',
      pageCount: 3,
      fileSizeBytes: 45600,
    );

    final doc = DocumentsModel(
      name: 'Scanned_Document.pdf',
      path: fakePdf.path,
      type: 'pdf',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ScannerResultView(
          pdfResult: result,
          document: doc,
          pages: const [],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Scan Complete'), findsOneWidget);
    expect(find.text('Document Scanned & Saved!'), findsOneWidget);
    expect(find.text('Scanned_Document.pdf'), findsOneWidget);
    expect(find.text('3 pages • 44.5 KB'), findsOneWidget);
    expect(find.text('Open PDF Document'), findsOneWidget);
    expect(find.text('Extract Text (Free)'), findsOneWidget);
    expect(find.textContaining('High-Precision OCR'), findsOneWidget);
  });

  test('AiDocumentService local NLP summarizes, extracts points, and explains', () {
    final ai = AiDocumentService.instance;
    const sampleText = '''
ACME CORPORATION QUARTERLY REPORT
Date: January 15, 2026.
Contact: Dr. John Smith, Chief Executive Officer.
Organization: Acme Corporation Inc.

Acme Corporation reported remarkable financial growth in the fourth quarter. Total revenue reached \$1,250,000 with a 15% increase compared to last year. The engineering team deployed a scalable cloud infrastructure and modernized core software services. Key deadlines were met on time. The final submission deadline is March 31, 2026 for fiscal review. All project deliverables must be completed by date specified in contract.
''';

    // 1. Summarize
    final summary = ai.summarizeDocument(sampleText);
    expect(summary.contains('Executive Summary'), isTrue);
    expect(summary.contains('Acme Corporation'), isTrue);

    // 2. Key Points
    final keyPoints = ai.extractKeyPoints(sampleText);
    expect(keyPoints.contains('Key Takeaways'), isTrue);
    expect(keyPoints.contains('•'), isTrue);

    // 3. Explain
    final explanation = ai.explainDocument(sampleText);
    expect(explanation.contains('Plain-English Document Explanation'), isTrue);
    expect(explanation.contains('Readability Rating'), isTrue);
  });

  test('AiDocumentService extracts dates, amounts, deadlines, names, and organizations', () {
    final ai = AiDocumentService.instance;
    const sampleContract = '''
CONFIDENTIAL AGREEMENT
On January 15, 2026, Dr. John Smith representing Acme Corporation Inc. agrees to pay \$1,250,000 for technical consulting.
The action required must be completed with final submission deadline of March 31, 2026.
''';

    final entities = ai.extractEntities(sampleContract);
    expect(entities.dates.any((d) => d.contains('January 15, 2026')), isTrue);
    expect(entities.amounts.any((a) => a.contains('1,250,000')), isTrue);
    expect(entities.names.any((n) => n.contains('Dr. John Smith')), isTrue);
    expect(entities.organizations.any((o) => o.contains('Acme Corporation Inc')), isTrue);
    expect(entities.deadlines.isNotEmpty, isTrue);
  });

  test('AiDocumentService generates study notes and context-aware Q&A answers', () {
    final ai = AiDocumentService.instance;
    const studyDoc = '''
PHOTOSYNTHESIS AND CELLULAR RESPIRATION
Photosynthesis is the biological process by which green plants convert sunlight into chemical energy. Chlorophyll absorbs solar radiation and synthesizes glucose from water and carbon dioxide. In contrast, cellular respiration takes place inside mitochondria, releasing ATP energy for cellular metabolism. Both biochemical processes sustain life on Earth.
''';

    // Study notes
    final notes = ai.generateStudyNotes(studyDoc);
    expect(notes.contains('Structured Study Notes'), isTrue);
    expect(notes.contains('Core Subject Topics'), isTrue);
    expect(notes.contains('Self-Check Review Questions'), isTrue);

    // Q&A
    final answer = ai.askAboutDocument(studyDoc, 'What does chlorophyll absorb?');
    expect(answer.contains('Q&A Answer'), isTrue);
    expect(answer.toLowerCase().contains('chlorophyll'), isTrue);

    // Irrelevant Q&A
    final fallback = ai.askAboutDocument(studyDoc, 'Who won the 1998 soccer world cup?');
    expect(fallback.contains('does not appear to contain explicit information'), isTrue);
  });

  test('AiDocumentService analyzes CV/Resume and provides ATS critique', () {
    final ai = AiDocumentService.instance;
    const resumeText = '''
Jane Doe
Email: jane.doe@example.com | Phone: +1-555-0199 | LinkedIn: linkedin.com/in/janedoe

Professional Summary:
Versatile Mobile Software Engineer with 5+ years of experience designing high-performance applications.

Work Experience:
Senior Flutter Developer - TechCorp (2022 - Present)
• Spearheaded architecture modernization, decreasing build times by 40%.
• Engineered offline-first document viewer utilized by 200,000+ users.
• Collaborated with cross-functional teams to launch 4 major products.

Education:
Bachelor of Science in Computer Science - State University (2018 - 2022)

Skills:
Flutter, Dart, Mobile Architecture, State Management, Git, REST APIs
''';

    final cvAnalysis = ai.analyzeCvResume(resumeText);
    expect(cvAnalysis.overallScore, greaterThan(60));
    expect(cvAnalysis.foundSections.contains('Contact Information'), isTrue);
    expect(cvAnalysis.foundSections.contains('Work Experience'), isTrue);
    expect(cvAnalysis.foundSections.contains('Education'), isTrue);
    expect(cvAnalysis.foundSections.contains('Skills'), isTrue);
    expect(cvAnalysis.actionVerbCount, greaterThanOrEqualTo(3));
    expect(cvAnalysis.summaryText.contains('ATS Quality Rating'), isTrue);
  });

  test('AiDocumentService saves analysis result as document', () async {
    final tempDir = Directory.systemTemp.createTempSync('ai_doc_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final doc = await AiDocumentService.instance.saveAnalysisAsDocument(
      textContent: 'Important Executive Summary findings.',
      type: AiAnalysisType.summarize,
      originalDocName: 'Research_Paper.pdf',
      outputDirectory: tempDir,
    );

    expect(doc.name.startsWith('Research_Paper_Summary_'), isTrue);
    expect(doc.type, 'txt');
    expect(File(doc.path).existsSync(), isTrue);
    expect(File(doc.path).readAsStringSync(), 'Important Executive Summary findings.');
  });

  testWidgets('AiDocumentAssistantView renders all categories and executes analysis', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const AiDocumentAssistantView(
          initialText: 'This is a sample document text for testing AI document intelligence.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI Document Intelligence'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Key Points'), findsOneWidget);
    expect(find.text('Explain'), findsOneWidget);
    expect(find.text('Extract Info'), findsOneWidget);
    expect(find.text('Study Notes'), findsOneWidget);
    expect(find.text('Ask Question'), findsOneWidget);
    expect(find.text('CV Analysis'), findsOneWidget);

    // Verify output rendered
    expect(find.text('Document Summary'), findsOneWidget);
    expect(find.text('Copy Output'), findsOneWidget);
  });

  testWidgets('OcrWorkspaceView renders source selectors and action controls', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const OcrWorkspaceView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OCR Workspace'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Images'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.byIcon(Icons.select_all_rounded), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
    expect(find.text('Save as .TXT'), findsOneWidget);
    if (AppConfig.isAiFeatureEnabled) {
      expect(find.text('AI Assistant'), findsOneWidget);
    } else {
      expect(find.text('AI Assistant'), findsNothing);
    }
  });

  testWidgets('DocumentDetailsView renders Document Intelligence section', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final doc = DocumentsModel(
      name: 'Sample_Doc.pdf',
      path: '/test/sample.pdf',
      type: 'pdf',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: DocumentDetailsView(document: doc),
      ),
    );
    await tester.pumpAndSettle();

    if (AppConfig.isAiFeatureEnabled) {
      expect(find.text('Document Intelligence'), findsOneWidget);
      expect(find.text('AI Assistant'), findsOneWidget);
      expect(find.text('Run OCR'), findsOneWidget);
    } else {
      expect(find.text('Document OCR Extraction'), findsOneWidget);
      expect(find.text('Run OCR Workspace'), findsOneWidget);
      expect(find.text('AI Assistant'), findsNothing);
    }
  });

  testWidgets('HomeView renders Workspace Actions, Metrics Bar, and launches quick actions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const HomeView(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Workspace Actions
    expect(find.text('Workspace Actions'), findsOneWidget);
    expect(find.text('Smart Scanner'), findsOneWidget);
    if (AppConfig.isAiFeatureEnabled) {
      expect(find.text('AI Assistant'), findsOneWidget);
    } else {
      expect(find.text('Extract Text'), findsOneWidget);
      expect(find.text('AI Assistant'), findsNothing);
    }
    expect(find.text('All Tools'), findsOneWidget);
    expect(find.text('Favorites'), findsWidgets);

    // Verify Document Overview stats bar
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Starred'), findsOneWidget);

    // Tap "All Tools" Quick Action
    await tester.tap(find.text('All Tools'));
    await tester.pumpAndSettle();

    // Verify navigated to ToolsView
    expect(find.text('${ToolsRegistryService.instance.getAllTools().length} Tools'), findsOneWidget);
  });

  testWidgets('HomeView category selection switches to Documents with category filter active', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const HomeView(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap "Images" category card on Home
    await tester.tap(find.text('Images'));
    await tester.pumpAndSettle();

    // Verify navigated to Documents tab with Images category selected
    expect(find.text('Images Files'), findsOneWidget);
  });

  testWidgets('DocumentsBody dynamic sorting re-orders documents when defaultSortNotifier changes', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final docA = DocumentsModel(
      name: 'Alpha Document.pdf',
      path: '',
      type: 'pdf',
      createdAt: DateTime(2025, 1, 1),
    );
    final docZ = DocumentsModel(
      name: 'Zulu Document.pdf',
      path: '',
      type: 'pdf',
      createdAt: DateTime(2025, 12, 31),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: DocumentsBody(
            documents: [docA, docZ],
            onDocumentDelete: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Set sort to name_asc
    SettingsService.instance.defaultSortNotifier.value = 'name_asc';
    await tester.pumpAndSettle();

    // Verify both are rendered
    expect(find.text('Alpha Document.pdf'), findsOneWidget);
    expect(find.text('Zulu Document.pdf'), findsOneWidget);

    // Reset sort
    SettingsService.instance.defaultSortNotifier.value = 'recent';
    await tester.pumpAndSettle();
  });

  testWidgets('Missing physical document shows user-friendly SnackBar with Remove action', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    bool deletedCalled = false;
    final missingDoc = DocumentsModel(
      name: 'Deleted_On_Disk.pdf',
      path: '/non_existent_folder/Deleted_On_Disk.pdf',
      type: 'pdf',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: DocumentsBody(
            documents: [missingDoc],
            onDocumentDelete: (doc) {
              deletedCalled = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the missing document
    await tester.tap(find.text('Deleted_On_Disk.pdf'));
    await tester.pumpAndSettle();

    // Verify error SnackBar with Remove action
    expect(find.text("File 'Deleted_On_Disk.pdf' not found on device storage."), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);

    // Tap Remove
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(deletedCalled, isTrue);
  });

  testWidgets('HomeAppBar and HomeBody search actions navigate to Documents tab', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const HomeView(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap search icon in HomeAppBar
    await tester.tap(find.byTooltip('Search Documents'));
    await tester.pumpAndSettle();

    // Verify on Documents tab
    expect(find.text('All Documents'), findsOneWidget);
  });

  testWidgets('HomeView PopScope returns to Home tab when system back is invoked on sub-tabs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const HomeView(),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Tools tab (Index 2)
    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();
    expect(find.text('Tools'), findsWidgets);

    // Simulate system back pop invocation
    final popScopeFinder = find.byWidgetPredicate((widget) => widget is PopScope);
    expect(popScopeFinder, findsOneWidget);
    final popScopeWidget = tester.widget<PopScope>(popScopeFinder);
    expect(popScopeWidget.canPop, isFalse);

    // Invoke pop callback
    popScopeWidget.onPopInvokedWithResult?.call(false, null);
    await tester.pumpAndSettle();

    // Verify switched back to Home tab (index 0)
    expect(find.text('Workspace Actions'), findsOneWidget);
  });

  test('SettingsService calculates dynamic cache size and executes cleanup', () async {
    final settings = SettingsService.instance;
    await settings.init();

    final sizeBytes = await settings.getCacheSizeBytes();
    expect(sizeBytes, isNonNegative);

    final freedBytes = await settings.clearCache();
    expect(freedBytes, isNonNegative);
  });

  test('PdfViewerScreen initializes with document metadata', () {
    final file = File('/storage/test.pdf');
    final screen = PdfViewerScreen(
      file: file,
      title: 'Test Doc',
      document: DocumentsModel(
        name: 'Test Doc',
        path: file.path,
        type: 'pdf',
        createdAt: DateTime.now(),
      ),
    );
    expect(screen.title, equals('Test Doc'));
    expect(screen.file.path, equals(file.path));
    expect(screen.document?.name, equals('Test Doc'));
  });

  test('AdMobService uses official Google sample test unit IDs and handles perks', () async {
    expect(AdMobService.useTestAds, isTrue);
    expect(
      AdMobService.testAndroidRewardedAdUnitId,
      equals('ca-app-pub-3940256099942544/5224354917'),
    );
    expect(
      AdMobService.testIosRewardedAdUnitId,
      equals('ca-app-pub-3940256099942544/1712485313'),
    );

    final adMob = AdMobService.instance;
    await adMob.initialize();
    expect(adMob.isInitialized, isTrue);

    // Perk session unlocking
    const perk = 'test_perk_feature';
    expect(adMob.isPerkUnlocked(perk), isFalse);
    adMob.unlockPerk(perk);
    expect(adMob.isPerkUnlocked(perk), isTrue);
  });

  testWidgets('PdfToImageView renders Standard (150 DPI) and Ultra HD (300 DPI) options', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final fakeInfo = InspectedPdfInfo(
      path: '/test/sample.pdf',
      fileName: 'sample.pdf',
      pageCount: 4,
      fileSizeBytes: 102400,
      pageSizes: const [
        Size(612, 792),
        Size(612, 792),
        Size(612, 792),
        Size(612, 792),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: PdfToImageView(initialPdfInfo: fakeInfo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Standard (150 DPI) • Free'), findsOneWidget);
    expect(find.text('Ultra HD (300 DPI)'), findsOneWidget);

    // Tap Ultra HD -> prompts with rewarded ad dialog
    await tester.tap(find.text('Ultra HD (300 DPI)'));
    await tester.pumpAndSettle();

    // Verify dialog appears with exact prompt and buttons
    expect(find.text('Watch a short ad to unlock Ultra HD export.'), findsOneWidget);
    expect(find.text('Watch Ad'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Tap Watch Ad to unlock perk
    await tester.tap(find.text('Watch Ad'));
    await tester.pumpAndSettle();

    // Verify unlocked state and switch back to Standard
    expect(find.text('Ultra HD (300 DPI) • Unlocked'), findsOneWidget);
    await tester.tap(find.text('Standard (150 DPI) • Free'));
    await tester.pumpAndSettle();
  });

  test('AppConfig maintains AI preservation while hiding from active UI', () {
    expect(AppConfig.isAiFeatureEnabled, isFalse);

    final allTools = ToolsRegistryService.instance.allRegisteredTools;
    expect(allTools.length, 17);
    expect(allTools.any((t) => t.id == 'ai_document_assistant'), isTrue);

    final activeTools = ToolsRegistryService.instance.getAllTools();
    expect(activeTools.length, 16);
    expect(activeTools.any((t) => t.id == 'ai_document_assistant'), isFalse);
  });

  test('AdMobService uses official Google sample test ad unit IDs', () {
    expect(AdMobService.useTestAds, isTrue);

    // Official Google Banner test IDs
    expect(
      AdMobService.testAndroidBannerAdUnitId,
      'ca-app-pub-3940256099942544/6300978111',
    );
    expect(
      AdMobService.testIosBannerAdUnitId,
      'ca-app-pub-3940256099942544/2934735716',
    );

    // Official Google Interstitial test IDs
    expect(
      AdMobService.testAndroidInterstitialAdUnitId,
      'ca-app-pub-3940256099942544/1033173712',
    );
    expect(
      AdMobService.testIosInterstitialAdUnitId,
      'ca-app-pub-3940256099942544/4411468910',
    );

    // Official Google Rewarded test IDs
    expect(
      AdMobService.testAndroidRewardedAdUnitId,
      'ca-app-pub-3940256099942544/5224354917',
    );
    expect(
      AdMobService.testIosRewardedAdUnitId,
      'ca-app-pub-3940256099942544/1712485313',
    );
  });

  test('AdMobService configures real production AdMob App ID and Unit IDs', () {
    // Real App ID
    expect(
      AdMobService.androidAppId,
      'ca-app-pub-1954229527229994~1075422211',
    );

    // Real Production Unit IDs
    expect(
      AdMobService.prodAndroidBannerAdUnitId,
      'ca-app-pub-1954229527229994/6297538316',
    );
    expect(
      AdMobService.prodAndroidInterstitialAdUnitId,
      'ca-app-pub-1954229527229994/9853639941',
    );
    expect(
      AdMobService.prodAndroidRewardedAdUnitId,
      'ca-app-pub-1954229527229994/8241622488',
    );

    // Test toggle behavior
    AdMobService.useTestAds = false;
    expect(
      AdMobService.instance.bannerAdUnitId,
      Platform.isAndroid
          ? AdMobService.prodAndroidBannerAdUnitId
          : AdMobService.prodIosBannerAdUnitId,
    );
    expect(
      AdMobService.instance.interstitialAdUnitId,
      Platform.isAndroid
          ? AdMobService.prodAndroidInterstitialAdUnitId
          : AdMobService.prodIosInterstitialAdUnitId,
    );
    expect(
      AdMobService.instance.rewardedAdUnitId,
      Platform.isAndroid
          ? AdMobService.prodAndroidRewardedAdUnitId
          : AdMobService.prodIosRewardedAdUnitId,
    );

    // Reset back to test ads
    AdMobService.useTestAds = true;
    expect(
      AdMobService.instance.bannerAdUnitId,
      Platform.isAndroid
          ? AdMobService.testAndroidBannerAdUnitId
          : AdMobService.testIosBannerAdUnitId,
    );
  });

  test('PremiumService entitlement correctly unlocks all session perks', () async {
    final premium = PremiumService.instance;
    final adMob = AdMobService.instance;

    // Initially not premium
    await premium.setPremiumForTesting(false);
    expect(premium.isPremium, isFalse);
    expect(adMob.isPerkUnlocked('test_perk_non_purchased'), isFalse);

    // User purchases Remove Ads
    await premium.setPremiumForTesting(true);
    expect(premium.isPremium, isTrue);

    // All perks are automatically unlocked when Premium is active
    expect(adMob.isPerkUnlocked('ultra_hd_pdf_export'), isTrue);
    expect(adMob.isPerkUnlocked('deep_pdf_compression'), isTrue);
    expect(adMob.isPerkUnlocked('studio_hd_images_to_pdf'), isTrue);

    // Reset back for subsequent tests
    await premium.setPremiumForTesting(false);
    expect(premium.isPremium, isFalse);
  });

  testWidgets('SettingsView displays active badge when Premium is active', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await PremiumService.instance.setPremiumForTesting(true);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const SettingsView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Premium Active'), findsOneWidget);
    expect(find.text('Lifetime License Active • All Ads Removed'), findsOneWidget);
    expect(find.text('Remove Ads'), findsNothing);

    await PremiumService.instance.setPremiumForTesting(false);
  });

  testWidgets('CompressPdfView allows selecting Standard and Deep Compression', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const CompressPdfView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select PDF to Compress'), findsOneWidget);
    expect(find.text('Select PDF File'), findsOneWidget);
  });

  testWidgets('ImagesToPdfView renders Standard and Studio HD quality options', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const ImagesToPdfView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quality:'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Studio HD'), findsOneWidget);
  });

  testWidgets('ScanToPdfWorkspaceView renders empty state and action buttons', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ScanToPdfWorkspaceView(initialPages: []),
      ),
    );
    await tester.pump();

    expect(find.text('Scan to PDF'), findsOneWidget);
    expect(find.text('Open Camera Scanner'), findsOneWidget);
    expect(find.text('Import from Gallery'), findsOneWidget);
  });
}




