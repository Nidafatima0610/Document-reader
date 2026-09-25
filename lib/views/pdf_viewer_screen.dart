import 'dart:io';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Unified production PDF Viewer screen honoring user reading preferences,
/// providing in-document search, page jump, fullscreen toggle, error recovery,
/// and external file opening.
class PdfViewerScreen extends StatefulWidget {
  final File file;
  final String title;
  final DocumentsModel? document;

  const PdfViewerScreen({
    super.key,
    required this.file,
    required this.title,
    this.document,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final SettingsService _settings = SettingsService.instance;
  final DocumentsStorageService _storage = DocumentsStorageService.instance;

  late bool _isFullscreen;
  int _currentPage = 1;
  int _pageCount = 0;
  bool _loadFailed = false;
  String _loadErrorMessage = '';

  // In-document text search state
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  PdfTextSearchResult? _searchResult;

  @override
  void initState() {
    super.initState();
    _isFullscreen = _settings.fullscreenReadingNotifier.value;
    if (widget.document != null) {
      _storage.recordDocumentOpened(widget.document!);
    }
  }

  @override
  void dispose() {
    _searchResult?.removeListener(_onSearchResultUpdate);
    _searchController.dispose();
    _pdfViewerController.dispose();
    super.dispose();
  }

  void _onSearchResultUpdate() {
    if (mounted) setState(() {});
  }

  void _startSearch(String text) {
    if (text.trim().isEmpty) {
      _searchResult?.clear();
      setState(() {});
      return;
    }

    _searchResult?.removeListener(_onSearchResultUpdate);
    _searchResult = _pdfViewerController.searchText(text);
    _searchResult!.addListener(_onSearchResultUpdate);
    setState(() {});
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchResult?.clear();
        _searchController.clear();
      }
    });
  }

  void _showJumpToPageDialog() {
    if (_pageCount <= 1) return;
    final textController = TextEditingController(text: '$_currentPage');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Jump to Page'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter page number (1 to $_pageCount):'),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: '1 - $_pageCount',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7046A8),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final page = int.tryParse(textController.text.trim());
                if (page != null && page >= 1 && page <= _pageCount) {
                  _pdfViewerController.jumpToPage(page);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a valid page number (1 - $_pageCount)'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
  }

  void _openInExternalApp() {
    OpenFilex.open(widget.file.path);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHorizontal = _settings.defaultViewModeNotifier.value == 'horizontal';
    final showPageNumbers = _settings.showPageNumbersNotifier.value;

    return Scaffold(
      appBar: _isFullscreen
          ? null
          : AppBar(
              title: _isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: const InputDecoration(
                        hintText: 'Search text in PDF...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: _startSearch,
                      textInputAction: TextInputAction.search,
                    )
                  : Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              actions: [
                if (_isSearching) ...[
                  if (_searchResult != null && _searchResult!.totalInstanceCount > 0) ...[
                    Center(
                      child: Text(
                        '${_searchResult!.currentInstanceIndex} of ${_searchResult!.totalInstanceCount}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up),
                      tooltip: 'Previous match',
                      onPressed: () => _searchResult?.previousInstance(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      tooltip: 'Next match',
                      onPressed: () => _searchResult?.nextInstance(),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close search',
                    onPressed: _toggleSearch,
                  ),
                ] else ...[
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'Search text',
                    onPressed: _toggleSearch,
                  ),
                  if (_pageCount > 1)
                    IconButton(
                      icon: const Icon(Icons.pin_outlined),
                      tooltip: 'Jump to page',
                      onPressed: _showJumpToPageDialog,
                    ),
                  if (widget.document != null)
                    ValueListenableBuilder<Set<String>>(
                      valueListenable: _storage.favoritesNotifier,
                      builder: (context, favs, _) {
                        final isFav = favs.contains(widget.document!.id);
                        return IconButton(
                          icon: Icon(
                            isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: isFav ? Colors.amber : null,
                          ),
                          tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
                          onPressed: () {
                            _storage.toggleFavorite(widget.document!);
                          },
                        );
                      },
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      switch (value) {
                        case 'fullscreen':
                          setState(() {
                            _isFullscreen = !_isFullscreen;
                          });
                          break;
                        case 'external':
                          _openInExternalApp();
                          break;
                        case 'jump':
                          _showJumpToPageDialog();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'fullscreen',
                        child: Row(
                          children: [
                            Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
                            const SizedBox(width: 8),
                            Text(_isFullscreen ? 'Exit Fullscreen' : 'Fullscreen'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'external',
                        child: Row(
                          children: [
                            Icon(Icons.open_in_new),
                            SizedBox(width: 8),
                            Text('Open with external app'),
                          ],
                        ),
                      ),
                      if (_pageCount > 1)
                        const PopupMenuItem(
                          value: 'jump',
                          child: Row(
                            children: [
                              Icon(Icons.format_list_numbered),
                              SizedBox(width: 8),
                              Text('Jump to page'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
      body: Stack(
        children: [
          if (_loadFailed)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to render PDF',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loadErrorMessage.isNotEmpty
                          ? _loadErrorMessage
                          : 'The PDF file may be corrupted, password-protected, or in an unsupported format.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7046A8),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _openInExternalApp,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open with External Viewer'),
                    ),
                  ],
                ),
              ),
            )
          else
            GestureDetector(
              onDoubleTap: () {
                // If in fullscreen, double tap or single tap toggles fullscreen back
                if (_isFullscreen) {
                  setState(() {
                    _isFullscreen = false;
                  });
                }
              },
              child: SfPdfViewer.file(
                widget.file,
                controller: _pdfViewerController,
                enableDoubleTapZooming: true,
                scrollDirection: isHorizontal
                    ? PdfScrollDirection.horizontal
                    : PdfScrollDirection.vertical,
                pageLayoutMode: isHorizontal
                    ? PdfPageLayoutMode.single
                    : PdfPageLayoutMode.continuous,
                onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                  setState(() {
                    _pageCount = details.document.pages.count;
                  });
                },
                onPageChanged: (PdfPageChangedDetails details) {
                  setState(() {
                    _currentPage = details.newPageNumber;
                  });
                },
                onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                  setState(() {
                    _loadFailed = true;
                    _loadErrorMessage = details.description;
                  });
                },
              ),
            ),

          // Floating page badge if enabled
          if (showPageNumbers && _pageCount > 0 && !_loadFailed)
            Positioned(
              bottom: 20,
              right: 20,
              child: AnimatedOpacity(
                opacity: 0.9,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : const Color(0xFF2D2435))
                        .withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '$_currentPage / $_pageCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          // Floating button to exit fullscreen if fullscreen is active
          if (_isFullscreen)
            Positioned(
              top: 40,
              left: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isFullscreen = false;
                    });
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
