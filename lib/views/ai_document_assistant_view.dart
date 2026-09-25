import 'dart:io';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/ai_document_service.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/pdf_operations_service.dart';
import 'package:all_documents_reader/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Screen providing the AI Document Intelligence Assistant
class AiDocumentAssistantView extends StatefulWidget {
  final DocumentsModel? initialDocument;
  final String? initialText;
  final AiAnalysisType initialType;

  const AiDocumentAssistantView({
    super.key,
    this.initialDocument,
    this.initialText,
    this.initialType = AiAnalysisType.summarize,
  });

  @override
  State<AiDocumentAssistantView> createState() => _AiDocumentAssistantViewState();
}

class _AiDocumentAssistantViewState extends State<AiDocumentAssistantView> {
  late AiAnalysisType _selectedType;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();

  DocumentsModel? _currentDocument;
  bool _isLoadingDocument = false;
  bool _isProcessing = false;
  bool _isSavedAsDoc = false;

  AiAnalysisResult? _currentResult;
  CvAnalysisResult? _cvResult;

  String _currentProvider = 'local';
  String? _geminiApiKey;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _currentDocument = widget.initialDocument;

    if (widget.initialText != null && widget.initialText!.trim().isNotEmpty) {
      _textController.text = widget.initialText!.trim();
      _runAnalysis();
    } else if (_currentDocument != null) {
      _loadTextFromDocument(_currentDocument!);
    }

    _loadAiSettings();
  }

  @override
  void dispose() {
    _textController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _loadAiSettings() async {
    final provider = await SettingsService.instance.getAiProvider();
    final key = await SettingsService.instance.getGeminiApiKey();
    if (mounted) {
      setState(() {
        _currentProvider = provider;
        _geminiApiKey = key;
      });
    }
  }

  Future<void> _loadTextFromDocument(DocumentsModel doc) async {
    setState(() {
      _isLoadingDocument = true;
      _currentDocument = doc;
      _currentResult = null;
      _cvResult = null;
      _isSavedAsDoc = false;
    });

    try {
      final file = File(doc.path);
      if (!file.existsSync()) {
        _showSnackBar('Document file does not exist on disk.');
        setState(() => _isLoadingDocument = false);
        return;
      }

      final lower = doc.name.toLowerCase();
      String extracted = '';

      if (lower.endsWith('.txt') || doc.type.toLowerCase() == 'txt') {
        extracted = await file.readAsString();
      } else if (lower.endsWith('.pdf') || doc.type.toLowerCase() == 'pdf') {
        final pdfRes = await PdfOperationsService.instance.extractTextFromPdf(pdfPath: doc.path);
        extracted = pdfRes.text;
      } else {
        // Sample or unsupported directly without OCR
        extracted = 'Selected: ${doc.name}\n(Path: ${doc.path})';
      }

      if (mounted) {
        setState(() {
          _textController.text = extracted.trim();
          _isLoadingDocument = false;
        });

        if (extracted.trim().isNotEmpty) {
          _runAnalysis();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDocument = false);
        _showSnackBar('Failed to read document text: $e');
      }
    }
  }

  Future<void> _runAnalysis() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showSnackBar('Please provide or select a document containing text.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _isSavedAsDoc = false;
      _cvResult = null;
    });

    try {
      if (_selectedType == AiAnalysisType.cvResume) {
        final cv = AiDocumentService.instance.analyzeCvResume(text);
        if (mounted) {
          setState(() {
            _cvResult = cv;
            _currentResult = AiAnalysisResult(
              type: AiAnalysisType.cvResume,
              textResult: cv.summaryText,
              isFromCloud: false,
              providerName: 'On-Device ATS Resume Analyzer',
              executionTimeMs: 40,
            );
            _isProcessing = false;
          });
        }
        return;
      }

      final result = await AiDocumentService.instance.processDocument(
        text: text,
        type: _selectedType,
        userQuestion: _selectedType == AiAnalysisType.askQuestion
            ? (_questionController.text.trim().isNotEmpty
                ? _questionController.text.trim()
                : 'What are the main key points in this document?')
            : null,
        forceLocal: _currentProvider == 'local',
      );

      if (mounted) {
        setState(() {
          _currentResult = result;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showSnackBar('Analysis failed: $e');
      }
    }
  }

  Future<void> _pickAnotherDocument() async {
    try {
      final docs = await DocumentsStorageService.instance.loadDocuments();
      if (!mounted) return;

      if (docs.isEmpty) {
        _showSnackBar('No documents found in library.');
        return;
      }

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'Select Document for AI Analysis',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (ctx, idx) {
                      final d = docs[idx];
                      final isSelected = d.path == _currentDocument?.path;
                      return ListTile(
                        leading: Icon(
                          d.type == 'pdf'
                              ? Icons.picture_as_pdf_rounded
                              : Icons.description_rounded,
                          color: isSelected ? Theme.of(context).primaryColor : null,
                        ),
                        title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(d.type.toUpperCase()),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          _loadTextFromDocument(d);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      _showSnackBar('Error loading documents: $e');
    }
  }

  Future<void> _configureApiKeyDialog() async {
    final keyController = TextEditingController(text: _geminiApiKey ?? '');
    String selectedProv = _currentProvider;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.tune_rounded, color: Color(0xFF7046A8)),
                  SizedBox(width: 10),
                  Text('AI Engine Settings'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose your preferred AI processing mode:',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => setDialogState(() => selectedProv = 'local'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selectedProv == 'local'
                              ? const Color(0xFF7046A8).withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedProv == 'local'
                                ? const Color(0xFF7046A8)
                                : Colors.grey.withValues(alpha: 0.3),
                            width: selectedProv == 'local' ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedProv == 'local'
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: selectedProv == 'local' ? const Color(0xFF7046A8) : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Smart Local NLP (Offline)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    '100% private, on-device, no API key needed',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => setDialogState(() => selectedProv = 'gemini'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selectedProv == 'gemini'
                              ? const Color(0xFF7046A8).withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedProv == 'gemini'
                                ? const Color(0xFF7046A8)
                                : Colors.grey.withValues(alpha: 0.3),
                            width: selectedProv == 'gemini' ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedProv == 'gemini'
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: selectedProv == 'gemini' ? const Color(0xFF7046A8) : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Google Gemini (Cloud AI)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    'Bring your own API key for cloud LLM reasoning',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (selectedProv == 'gemini') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: keyController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Gemini API Key',
                          hintText: 'AIzaSy...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          helperText: 'Saved securely on your device. Never shared.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_outlined, color: Colors.amber, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Document text is sent to Google Gemini only when Cloud AI is explicitly selected.',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await SettingsService.instance.setAiProvider(selectedProv);
                    await SettingsService.instance.setGeminiApiKey(keyController.text.trim());
                    if (mounted) {
                      setState(() {
                        _currentProvider = selectedProv;
                        _geminiApiKey = keyController.text.trim();
                      });
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save Settings'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _copyResult() async {
    if (_currentResult == null) return;
    await Clipboard.setData(ClipboardData(text: _currentResult!.textResult));
    _showSnackBar('Analysis result copied to clipboard!');
  }

  Future<void> _saveAsDocument() async {
    if (_currentResult == null || _isSavedAsDoc) return;

    try {
      final doc = await AiDocumentService.instance.saveAnalysisAsDocument(
        textContent: _currentResult!.textResult,
        type: _selectedType,
        originalDocName: _currentDocument?.name,
      );

      if (!mounted) return;
      setState(() => _isSavedAsDoc = true);
      _showSnackBar('Saved "${doc.name}" to Documents!');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to save document: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = theme.primaryColor;
    final surfaceColor = isDark ? const Color(0xFF1E1926) : Colors.white;
    final bgLight = isDark ? const Color(0xFF14101A) : const Color(0xFFF7F6FA);

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: Color(0xFF9D65E5), size: 22),
            SizedBox(width: 8),
            Text('AI Document Intelligence'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'AI Engine Settings',
            onPressed: _configureApiKeyDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Engine & Document Selector Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.description_outlined, color: primaryColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentDocument != null
                                  ? _currentDocument!.name
                                  : (_textController.text.isNotEmpty
                                      ? 'Custom Input Text'
                                      : 'No Document Loaded'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _currentProvider == 'gemini' &&
                                      _geminiApiKey != null &&
                                      _geminiApiKey!.isNotEmpty
                                  ? 'Cloud Engine: Google Gemini'
                                  : 'On-Device Engine: 100% Offline & Private',
                              style: TextStyle(
                                fontSize: 11,
                                color: _currentProvider == 'gemini'
                                    ? Colors.blue
                                    : const Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _pickAnotherDocument,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: const Size(60, 32),
                        ),
                        child: const Text('Change', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  if (_isLoadingDocument) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Action Category Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: AiAnalysisType.values.map((type) {
                  final isSelected = _selectedType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(type.shortLabel),
                      selected: isSelected,
                      onSelected: (sel) {
                        if (sel) {
                          setState(() => _selectedType = type);
                          _runAnalysis();
                        }
                      },
                      selectedColor: primaryColor,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12.5,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // 3. Question Input (Only if askQuestion is active)
            if (_selectedType == AiAnalysisType.askQuestion) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ask about this document:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _questionController,
                            decoration: const InputDecoration(
                              hintText: 'e.g., What are the main terms or deadlines?',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _runAnalysis(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _runAnalysis,
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        'What is the key takeaway?',
                        'What are the deadlines?',
                        'Who are the parties involved?',
                      ].map((prompt) {
                        return ActionChip(
                          label: Text(prompt, style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            _questionController.text = prompt;
                            _runAnalysis();
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 4. Output Results Area
            if (_isProcessing) ...[
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: primaryColor),
                    const SizedBox(height: 16),
                    Text(
                      'Analyzing document content with ${_currentProvider == 'gemini' ? 'Google Gemini' : 'Local Smart NLP'}...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Extracting key premises, entities, and structural semantics',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ] else if (_currentResult != null) ...[
              // Results Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedType.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        tooltip: 'Copy Result',
                        onPressed: _copyResult,
                      ),
                      IconButton(
                        icon: Icon(
                          _isSavedAsDoc ? Icons.check_circle : Icons.save_alt_rounded,
                          color: _isSavedAsDoc ? Colors.green : null,
                          size: 20,
                        ),
                        tooltip: 'Save as Document',
                        onPressed: _saveAsDocument,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Warning or Fallback Message
              if (_currentResult!.warningMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentResult!.warningMessage!,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // CV Results Special Visual Badge
              if (_cvResult != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withValues(alpha: 0.15),
                        primaryColor.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${_cvResult!.overallScore}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ATS Resume Quality Score',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              '${_cvResult!.foundSections.length} sections found • ${_cvResult!.actionVerbCount} action verbs utilized',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Main Formatted Text Output Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: SelectableText(
                  _currentResult!.textResult,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF2D2435),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bottom Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyResult,
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Output'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSavedAsDoc ? null : _saveAsDocument,
                      icon: Icon(
                        _isSavedAsDoc ? Icons.check : Icons.save_rounded,
                        size: 16,
                      ),
                      label: Text(_isSavedAsDoc ? 'Saved' : 'Save as Document'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Empty State
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 48,
                      color: primaryColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Ready to Analyze Document',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Select an analysis mode above to summarize, extract key points, or ask questions about this document.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: _runAnalysis,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Run Analysis Now'),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
