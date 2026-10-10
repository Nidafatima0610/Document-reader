import 'dart:io';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/document_save_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DocumentsStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('doc_test_');
    storage = DocumentsStorageService.instance;
    await storage.loadFavorites();
    await storage.loadRecentDocuments();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Safe Document Deletion Tests', () {
    test('removeFromApp removes metadata and references but preserves physical file', () async {
      // 1. Create a physical file
      final testFile = File('${tempDir.path}/important_contract.pdf');
      await testFile.writeAsString('Contract content');
      expect(testFile.existsSync(), isTrue);

      final doc = DocumentsModel(
        name: 'important_contract.pdf',
        path: testFile.path,
        type: 'pdf',
        createdAt: DateTime.now(),
      );

      // Add to storage, recents, and favorites
      await storage.saveDocuments([doc]);
      await storage.recordDocumentOpened(doc);
      await storage.toggleFavorite(doc);

      expect(storage.isFavorite(doc), isTrue);
      expect(storage.recentDocumentsNotifier.value.any((d) => d.id == doc.id), isTrue);

      // Perform "Remove from App"
      final result = await storage.removeFromApp(doc);

      expect(result.success, isTrue);
      expect(result.type, DocumentDeleteType.removeFromApp);
      // CRITICAL RULE: Physical file MUST still exist!
      expect(testFile.existsSync(), isTrue);

      // References must be purged
      expect(storage.isFavorite(doc), isFalse);
      expect(storage.recentDocumentsNotifier.value.any((d) => d.id == doc.id), isFalse);
      expect(storage.documentsNotifier.value.any((d) => d.id == doc.id), isFalse);
    });

    test('deleteFilePermanently deletes physical file and purges all references', () async {
      // 1. Create a physical file
      final testFile = File('${tempDir.path}/delete_me.pdf');
      await testFile.writeAsString('Disposable content');
      expect(testFile.existsSync(), isTrue);

      final doc = DocumentsModel(
        name: 'delete_me.pdf',
        path: testFile.path,
        type: 'pdf',
        createdAt: DateTime.now(),
      );

      // Add to storage, recents, and favorites
      await storage.saveDocuments([doc]);
      await storage.recordDocumentOpened(doc);
      await storage.toggleFavorite(doc);

      // Perform "Delete File Permanently"
      final result = await storage.deleteFilePermanently(doc);

      expect(result.success, isTrue);
      expect(result.type, DocumentDeleteType.deletePermanently);
      // Physical file MUST BE GONE
      expect(testFile.existsSync(), isFalse);

      // References must be purged
      expect(storage.isFavorite(doc), isFalse);
      expect(storage.recentDocumentsNotifier.value.any((d) => d.id == doc.id), isFalse);
      expect(storage.documentsNotifier.value.any((d) => d.id == doc.id), isFalse);
    });

    test('deleteFilePermanently safely refuses directories or root paths', () async {
      final subDir = Directory('${tempDir.path}/sub_folder');
      await subDir.create();

      final invalidDoc = DocumentsModel(
        name: 'sub_folder',
        path: subDir.path,
        type: 'pdf',
        createdAt: DateTime.now(),
      );

      final result = await storage.deleteFilePermanently(invalidDoc);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('directory'));
      // Directory MUST NOT be deleted
      expect(subDir.existsSync(), isTrue);
    });

    test('deleteFilePermanently handles already missing file gracefully', () async {
      final ghostDoc = DocumentsModel(
        name: 'ghost.pdf',
        path: '${tempDir.path}/ghost.pdf',
        type: 'pdf',
        createdAt: DateTime.now(),
      );

      await storage.saveDocuments([ghostDoc]);
      final result = await storage.deleteFilePermanently(ghostDoc);

      expect(result.success, isTrue);
      expect(storage.documentsNotifier.value.any((d) => d.id == ghostDoc.id), isFalse);
    });
  });

  group('Document Save Service Tests', () {
    test('generateUniqueFileName prevents collision when destination file exists', () {
      final existingFile = File('${tempDir.path}/Contract.pdf');
      existingFile.writeAsStringSync('existing');

      final safeName = DocumentSaveService.instance.generateUniqueFileName(
        directory: tempDir,
        baseName: 'Contract.pdf',
      );

      expect(safeName, isNot('Contract.pdf'));
      expect(safeName, contains('Contract (1).pdf'));
    });

    test('generateUniqueFileName keeps name when no collision exists', () {
      final safeName = DocumentSaveService.instance.generateUniqueFileName(
        directory: tempDir,
        baseName: 'BrandNew.pdf',
      );

      expect(safeName, 'BrandNew.pdf');
    });
  });
}
