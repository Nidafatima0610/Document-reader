import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/document_save_service.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/smart_document_formatter_service.dart';
import 'package:all_documents_reader/widgets/generated_pdf_success_sheet.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class SmartDocumentFormatterView extends StatefulWidget {
  final String? initialText;

  const SmartDocumentFormatterView({super.key, this.initialText});

  @override
  State<SmartDocumentFormatterView> createState() => _SmartDocumentFormatterViewState();
}

class _SmartDocumentFormatterViewState extends State<SmartDocumentFormatterView> {
  final TextEditingController _titleController = TextEditingController(text: 'Formatted Document');
  final TextEditingController _authorController = TextEditingController();
  final List<FormatterSection> _sections = [];
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null && widget.initialText!.trim().isNotEmpty) {
      _importRawText(widget.initialText!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  void _importRawText(String rawText) {
    _sections.clear();
    final blocks = rawText.split(RegExp(r'\n\s*\n'));
    int idCounter = 1;

    for (final block in blocks) {
      final clean = block.trim();
      if (clean.isEmpty) continue;

      if (clean.startsWith('# ') || (clean.length < 40 && !clean.contains('.'))) {
        _sections.add(
          FormatterSection(
            id: '${idCounter++}',
            type: DocumentSectionType.heading1,
            text: clean.replaceAll('# ', ''),
          ),
        );
      } else if (clean.startsWith('## ')) {
        _sections.add(
          FormatterSection(
            id: '${idCounter++}',
            type: DocumentSectionType.heading2,
            text: clean.replaceAll('## ', ''),
          ),
        );
      } else if (clean.startsWith('• ') || clean.startsWith('- ')) {
        final lines = clean
            .split('\n')
            .map((l) => l.replaceAll(RegExp(r'^[•\-\*]\s*'), '').trim())
            .where((l) => l.isNotEmpty)
            .toList();
        _sections.add(
          FormatterSection(
            id: '${idCounter++}',
            type: DocumentSectionType.bulletList,
            listItems: lines,
          ),
        );
      } else {
        _sections.add(
          FormatterSection(
            id: '${idCounter++}',
            type: DocumentSectionType.paragraph,
            text: clean,
          ),
        );
      }
    }
  }

  void _addSection(DocumentSectionType type) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    switch (type) {
      case DocumentSectionType.heading1:
        _showTextPromptDialog(
          title: 'Add Heading (H1)',
          hint: 'Enter section heading...',
          onConfirm: (val) {
            setState(() {
              _sections.add(FormatterSection(id: id, type: type, text: val));
            });
          },
        );
        break;

      case DocumentSectionType.heading2:
        _showTextPromptDialog(
          title: 'Add Subheading (H2)',
          hint: 'Enter subheading...',
          onConfirm: (val) {
            setState(() {
              _sections.add(FormatterSection(id: id, type: type, text: val));
            });
          },
        );
        break;

      case DocumentSectionType.paragraph:
        _showTextPromptDialog(
          title: 'Add Paragraph',
          hint: 'Enter paragraph text...',
          maxLines: 5,
          onConfirm: (val) {
            setState(() {
              _sections.add(FormatterSection(id: id, type: type, text: val));
            });
          },
        );
        break;

      case DocumentSectionType.bulletList:
        _showTextPromptDialog(
          title: 'Add Bullet List',
          hint: 'Enter items, one per line...',
          maxLines: 5,
          onConfirm: (val) {
            final items = val.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
            setState(() {
              _sections.add(FormatterSection(id: id, type: type, listItems: items));
            });
          },
        );
        break;

      case DocumentSectionType.table:
        _showTableCreatorDialog(id);
        break;

      case DocumentSectionType.divider:
        setState(() {
          _sections.add(FormatterSection(id: id, type: type));
        });
        break;

      case DocumentSectionType.title:
        break;
    }
  }

  void _editSection(int index) {
    final sec = _sections[index];
    switch (sec.type) {
      case DocumentSectionType.heading1:
      case DocumentSectionType.heading2:
      case DocumentSectionType.title:
        _showTextPromptDialog(
          title: 'Edit ${sec.type == DocumentSectionType.heading1 ? "Heading (H1)" : "Subheading (H2)"}',
          hint: 'Enter heading text...',
          initialValue: sec.text,
          onConfirm: (val) {
            setState(() => sec.text = val);
          },
        );
        break;

      case DocumentSectionType.paragraph:
        _showTextPromptDialog(
          title: 'Edit Paragraph',
          hint: 'Enter paragraph text...',
          initialValue: sec.text,
          maxLines: 6,
          onConfirm: (val) {
            setState(() => sec.text = val);
          },
        );
        break;

      case DocumentSectionType.bulletList:
        _showTextPromptDialog(
          title: 'Edit Bullet List',
          hint: 'Enter items, one per line...',
          initialValue: sec.listItems.join('\n'),
          maxLines: 6,
          onConfirm: (val) {
            final items = val.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
            setState(() => sec.listItems = items);
          },
        );
        break;

      case DocumentSectionType.table:
        _showTableEditorDialog(sec);
        break;

      case DocumentSectionType.divider:
        break;
    }
  }

  void _moveSection(int from, int to) {
    if (to < 0 || to >= _sections.length) return;
    setState(() {
      final item = _sections.removeAt(from);
      _sections.insert(to, item);
    });
  }

  void _showTextPromptDialog({
    required String title,
    required String hint,
    String? initialValue,
    int maxLines = 1,
    required ValueChanged<String> onConfirm,
  }) {
    final controller = TextEditingController(text: initialValue ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: maxLines,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7046A8),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                onConfirm(text);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showTableCreatorDialog(String id) {
    int rows = 3;
    int cols = 3;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Create New Table', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Columns:'),
                  DropdownButton<int>(
                    value: cols,
                    items: [2, 3, 4, 5, 6].map((c) => DropdownMenuItem(value: c, child: Text('$c Columns'))).toList(),
                    onChanged: (val) => setDialogState(() => cols = val ?? 3),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Data Rows:'),
                  DropdownButton<int>(
                    value: rows,
                    items: [1, 2, 3, 4, 5, 6, 8, 10].map((r) => DropdownMenuItem(value: r, child: Text('$r Rows'))).toList(),
                    onChanged: (val) => setDialogState(() => rows = val ?? 3),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7046A8), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(dialogCtx);
                final matrix = <List<String>>[];
                // Header row
                matrix.add(List.generate(cols, (c) => 'Column ${c + 1}'));
                // Data rows
                for (int r = 0; r < rows; r++) {
                  matrix.add(List.generate(cols, (c) => 'Data ${r + 1},${c + 1}'));
                }
                setState(() {
                  _sections.add(
                    FormatterSection(
                      id: id,
                      type: DocumentSectionType.table,
                      tableData: matrix,
                    ),
                  );
                });
              },
              child: const Text('Create Table'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTableEditorDialog(FormatterSection section) {
    final matrix = List<List<String>>.from(
      section.tableData.map((row) => List<String>.from(row)),
    );

    if (matrix.isEmpty) {
      matrix.add(['Column 1', 'Column 2']);
      matrix.add(['Cell 1', 'Cell 2']);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final colCount = matrix.first.length;
          final rowCount = matrix.length;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Edit Table', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  '$rowCount rows × $colCount cols',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7046A8), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 380,
              child: Column(
                children: [
                  // Row & Column Editing Controls
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7046A8).withValues(alpha: 0.12),
                            foregroundColor: const Color(0xFF7046A8),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          onPressed: () {
                            setDialogState(() {
                              matrix.add(List.generate(colCount, (c) => 'Row $rowCount, Col ${c + 1}'));
                            });
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('+ Row', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.withValues(alpha: 0.1),
                            foregroundColor: Colors.red,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          onPressed: rowCount > 2
                              ? () {
                                  setDialogState(() {
                                    matrix.removeLast();
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.remove, size: 16),
                          label: const Text('- Row', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7046A8).withValues(alpha: 0.12),
                            foregroundColor: const Color(0xFF7046A8),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          onPressed: colCount < 6
                              ? () {
                                  setDialogState(() {
                                    matrix.first.add('Col ${colCount + 1}');
                                    for (int r = 1; r < matrix.length; r++) {
                                      matrix[r].add('Data $r,${colCount + 1}');
                                    }
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('+ Col', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.withValues(alpha: 0.1),
                            foregroundColor: Colors.red,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          onPressed: colCount > 2
                              ? () {
                                  setDialogState(() {
                                    for (int r = 0; r < matrix.length; r++) {
                                      matrix[r].removeLast();
                                    }
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.remove, size: 16),
                          label: const Text('- Col', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Text(
                    'Tap any cell below to edit its text:',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),

                  // Interactive Table Matrix
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFF7046A8).withValues(alpha: 0.1)),
                            columns: List.generate(matrix.first.length, (c) {
                              return DataColumn(
                                label: InkWell(
                                  onTap: () {
                                    _editTableCellValue(matrix.first[c], (newVal) {
                                      setDialogState(() {
                                        matrix.first[c] = newVal;
                                      });
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      Text(
                                        matrix.first[c],
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7046A8)),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.edit, size: 12, color: Color(0xFF7046A8)),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            rows: List.generate(matrix.length - 1, (rIndex) {
                              final row = matrix[rIndex + 1];
                              return DataRow(
                                cells: List.generate(row.length, (cIndex) {
                                  return DataCell(
                                    Row(
                                      children: [
                                        Text(row[cIndex]),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.edit, size: 11, color: Colors.grey),
                                      ],
                                    ),
                                    onTap: () {
                                      _editTableCellValue(row[cIndex], (newVal) {
                                        setDialogState(() {
                                          matrix[rIndex + 1][cIndex] = newVal;
                                        });
                                      });
                                    },
                                  );
                                }),
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7046A8), foregroundColor: Colors.white),
                onPressed: () {
                  setState(() {
                    section.tableData = matrix;
                  });
                  Navigator.pop(dialogCtx);
                  _showSnackBar('Table updated');
                },
                child: const Text('Save Table'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editTableCellValue(String initial, ValueChanged<String> onSaved) {
    final controller = TextEditingController(text: initial);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Cell Text', style: TextStyle(fontSize: 15)),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7046A8), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              onSaved(controller.text.trim());
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndPreviewPdf() async {
    if (_sections.isEmpty) {
      _showSnackBar('Add at least one section before generating PDF.');
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final result = await SmartDocumentFormatterService.instance.generateFormattedPdf(
        sections: _sections,
        options: SmartFormatterOptions(
          documentTitle: _titleController.text.trim(),
          author: _authorController.text.trim(),
        ),
      );

      setState(() => _isGenerating = false);
      if (!mounted) return;

      // Show preview sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              AppBar(
                title: Text(result.fileName),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Expanded(
                child: SfPdfViewer.file(result.file),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await DocumentSaveService.instance.saveDocumentToDevice(
                              context: context,
                              sourceFile: result.file,
                              defaultFileName: result.fileName,
                            );
                          },
                          icon: const Icon(Icons.save_alt_rounded),
                          label: const Text('Save to Device'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7046A8),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            final doc = DocumentsModel(
                              name: result.fileName,
                              path: result.file.path,
                              type: 'pdf',
                              createdAt: DateTime.now(),
                            );
                            DocumentsStorageService.instance.addDocument(doc);
                            GeneratedPdfSuccessSheet.show(
                              context: context,
                              document: doc,
                              file: result.file,
                              subtitle: '${result.pageCount} pages • ${result.formattedSize}',
                              onDone: () => Navigator.pop(context),
                            );
                          },
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Finish & Register'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      setState(() => _isGenerating = false);
      _showSnackBar('Document generation failed: $e');
    }
  }

  Future<void> _saveDocumentDirectly() async {
    if (_sections.isEmpty) {
      _showSnackBar('Add at least one section before generating PDF.');
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final result = await SmartDocumentFormatterService.instance.generateFormattedPdf(
        sections: _sections,
        options: SmartFormatterOptions(
          documentTitle: _titleController.text.trim().isEmpty ? 'Formatted Document' : _titleController.text.trim(),
          author: _authorController.text.trim(),
        ),
      );

      final doc = DocumentsModel(
        name: result.fileName,
        path: result.file.path,
        type: 'pdf',
        createdAt: DateTime.now(),
      );
      await DocumentsStorageService.instance.addDocument(doc);

      setState(() => _isGenerating = false);
      if (!mounted) return;

      GeneratedPdfSuccessSheet.show(
        context: context,
        document: doc,
        file: result.file,
        subtitle: '${result.pageCount} pages • ${result.formattedSize}',
        onDone: () => Navigator.pop(context),
      );
    } catch (e) {
      setState(() => _isGenerating = false);
      _showSnackBar('Document generation failed: $e');
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF211C29) : Colors.white;

    return PopScope(
      canPop: _sections.isEmpty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Discard Document?'),
            content: Text('You have ${_sections.length} content block(s) in this document. Leaving now will discard your work.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Editing')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (discard == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Smart Formatter & Tables', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              Text('Create documents & tables as clean PDF', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.visibility_rounded),
              tooltip: 'Preview PDF',
              onPressed: _isGenerating || _sections.isEmpty ? null : _generateAndPreviewPdf,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          // Document Header Configuration
          Card(
            color: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Document Setup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Document Title',
                      prefixIcon: Icon(Icons.title_rounded, color: Color(0xFF7046A8)),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _authorController,
                    decoration: const InputDecoration(
                      labelText: 'Author / Organization (Optional)',
                      prefixIcon: Icon(Icons.person_outline_rounded, color: Color(0xFF7046A8)),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Insert Controls Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildActionChip(Icons.format_size_rounded, 'Heading 1', () => _addSection(DocumentSectionType.heading1)),
                const SizedBox(width: 8),
                _buildActionChip(Icons.text_fields_rounded, 'Heading 2', () => _addSection(DocumentSectionType.heading2)),
                const SizedBox(width: 8),
                _buildActionChip(Icons.notes_rounded, 'Paragraph', () => _addSection(DocumentSectionType.paragraph)),
                const SizedBox(width: 8),
                _buildActionChip(Icons.table_chart_rounded, 'Table', () => _addSection(DocumentSectionType.table)),
                const SizedBox(width: 8),
                _buildActionChip(Icons.format_list_bulleted_rounded, 'Bullets', () => _addSection(DocumentSectionType.bulletList)),
                const SizedBox(width: 8),
                _buildActionChip(Icons.horizontal_rule_rounded, 'Divider', () => _addSection(DocumentSectionType.divider)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Structured Section List or Clean Empty State
          if (_sections.isEmpty)
            _buildEmptyState(isDark, cardBg)
          else ...[
            Text(
              'Document Flow (${_sections.length} sections):',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ..._sections.asMap().entries.map((entry) {
              final idx = entry.key;
              final sec = entry.value;
              final isFirst = idx == 0;
              final isLast = idx == _sections.length - 1;

              return Card(
                color: cardBg,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: _getSectionIcon(sec.type),
                  title: Text(
                    _getSectionTitle(sec),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    _getSectionSubtitle(sec),
                    style: const TextStyle(fontSize: 10, color: Color(0xFF7046A8), fontWeight: FontWeight.bold),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Move Up
                      IconButton(
                        icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                        tooltip: 'Move Up',
                        onPressed: isFirst ? null : () => _moveSection(idx, idx - 1),
                      ),
                      // Move Down
                      IconButton(
                        icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                        tooltip: 'Move Down',
                        onPressed: isLast ? null : () => _moveSection(idx, idx + 1),
                      ),
                      // Edit Button (available on all non-divider blocks!)
                      if (sec.type != DocumentSectionType.divider)
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, color: Color(0xFF7046A8), size: 18),
                          tooltip: 'Edit Section',
                          onPressed: () => _editSection(idx),
                        ),
                      // Delete Button
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                        tooltip: 'Delete',
                        onPressed: () => setState(() => _sections.removeAt(idx)),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _isGenerating || _sections.isEmpty ? null : _generateAndPreviewPdf,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Preview'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7046A8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isGenerating || _sections.isEmpty ? null : _saveDocumentDirectly,
                  icon: _isGenerating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text(
                    _sections.isEmpty
                        ? 'Save as PDF'
                        : _isGenerating
                            ? 'Saving...'
                            : 'Save as PDF (${_sections.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildEmptyState(bool isDark, Color cardBg) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7046A8).withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF7046A8).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.post_add_rounded, size: 32, color: Color(0xFF7046A8)),
          ),
          const SizedBox(height: 14),
          const Text(
            'Start Building Your Document',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Compose clean, multi-page PDFs with headings, paragraphs, bullet lists, and tables.\nTap any option below to add your first block:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.grey[600], height: 1.4),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ActionChip(
                avatar: const Icon(Icons.format_size_rounded, size: 16, color: Color(0xFF7046A8)),
                label: const Text('+ Heading'),
                onPressed: () => _addSection(DocumentSectionType.heading1),
              ),
              ActionChip(
                avatar: const Icon(Icons.notes_rounded, size: 16, color: Color(0xFF7046A8)),
                label: const Text('+ Paragraph'),
                onPressed: () => _addSection(DocumentSectionType.paragraph),
              ),
              ActionChip(
                avatar: const Icon(Icons.table_chart_rounded, size: 16, color: Color(0xFF7046A8)),
                label: const Text('+ Table'),
                onPressed: () => _addSection(DocumentSectionType.table),
              ),
              ActionChip(
                avatar: const Icon(Icons.format_list_bulleted_rounded, size: 16, color: Color(0xFF7046A8)),
                label: const Text('+ Bullets'),
                onPressed: () => _addSection(DocumentSectionType.bulletList),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(IconData icon, String label, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: const Color(0xFF7046A8)),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      onPressed: onTap,
    );
  }

  Widget _getSectionIcon(DocumentSectionType type) {
    switch (type) {
      case DocumentSectionType.heading1:
      case DocumentSectionType.heading2:
        return const Icon(Icons.title_rounded, color: Color(0xFF7046A8));
      case DocumentSectionType.paragraph:
        return const Icon(Icons.notes_rounded, color: Color(0xFF7046A8));
      case DocumentSectionType.bulletList:
        return const Icon(Icons.format_list_bulleted_rounded, color: Color(0xFF7046A8));
      case DocumentSectionType.table:
        return const Icon(Icons.table_chart_rounded, color: Color(0xFF7046A8));
      case DocumentSectionType.divider:
        return const Icon(Icons.horizontal_rule_rounded, color: Color(0xFF7046A8));
      case DocumentSectionType.title:
        return const Icon(Icons.article_rounded, color: Color(0xFF7046A8));
    }
  }

  String _getSectionTitle(FormatterSection sec) {
    switch (sec.type) {
      case DocumentSectionType.heading1:
      case DocumentSectionType.heading2:
      case DocumentSectionType.paragraph:
      case DocumentSectionType.title:
        return sec.text;
      case DocumentSectionType.bulletList:
        return sec.listItems.join(', ');
      case DocumentSectionType.table:
        final r = sec.tableData.length;
        final c = sec.tableData.isNotEmpty ? sec.tableData.first.length : 0;
        return '$r rows × $c columns table';
      case DocumentSectionType.divider:
        return 'Horizontal Page Separator';
    }
  }

  String _getSectionSubtitle(FormatterSection sec) {
    switch (sec.type) {
      case DocumentSectionType.heading1:
        return 'HEADING 1';
      case DocumentSectionType.heading2:
        return 'HEADING 2';
      case DocumentSectionType.paragraph:
        return 'PARAGRAPH';
      case DocumentSectionType.bulletList:
        return 'BULLET LIST (${sec.listItems.length} items)';
      case DocumentSectionType.table:
        final r = sec.tableData.length;
        final c = sec.tableData.isNotEmpty ? sec.tableData.first.length : 0;
        return 'TABLE ($r×$c)';
      case DocumentSectionType.divider:
        return 'DIVIDER LINE';
      case DocumentSectionType.title:
        return 'TITLE';
    }
  }
}
