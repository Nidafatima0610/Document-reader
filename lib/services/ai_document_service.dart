import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:all_documents_reader/models/documents_model.dart';
import 'package:all_documents_reader/services/documents_storage_service.dart';
import 'package:all_documents_reader/services/settings_service.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Supported types of AI document processing
enum AiAnalysisType {
  summarize,
  keyPoints,
  explain,
  extractInfo,
  studyNotes,
  askQuestion,
  cvResume,
}

extension AiAnalysisTypeExtension on AiAnalysisType {
  String get title {
    switch (this) {
      case AiAnalysisType.summarize:
        return 'Document Summary';
      case AiAnalysisType.keyPoints:
        return 'Key Points & Takeaways';
      case AiAnalysisType.explain:
        return 'Plain Language Explanation';
      case AiAnalysisType.extractInfo:
        return 'Extracted Entities & Info';
      case AiAnalysisType.studyNotes:
        return 'Structured Study Notes';
      case AiAnalysisType.askQuestion:
        return 'Document Q&A';
      case AiAnalysisType.cvResume:
        return 'CV / Resume Analysis';
    }
  }

  String get shortLabel {
    switch (this) {
      case AiAnalysisType.summarize:
        return 'Summary';
      case AiAnalysisType.keyPoints:
        return 'Key Points';
      case AiAnalysisType.explain:
        return 'Explain';
      case AiAnalysisType.extractInfo:
        return 'Extract Info';
      case AiAnalysisType.studyNotes:
        return 'Study Notes';
      case AiAnalysisType.askQuestion:
        return 'Ask Question';
      case AiAnalysisType.cvResume:
        return 'CV Analysis';
    }
  }
}

/// Structured entity extraction outcome
class ExtractedDocumentInfo {
  final List<String> names;
  final List<String> dates;
  final List<String> amounts;
  final List<String> deadlines;
  final List<String> organizations;
  final List<String> headings;

  const ExtractedDocumentInfo({
    this.names = const [],
    this.dates = const [],
    this.amounts = const [],
    this.deadlines = const [],
    this.organizations = const [],
    this.headings = const [],
  });

  bool get isEmpty =>
      names.isEmpty &&
      dates.isEmpty &&
      amounts.isEmpty &&
      deadlines.isEmpty &&
      organizations.isEmpty &&
      headings.isEmpty;

  int get totalCount =>
      names.length +
      dates.length +
      amounts.length +
      deadlines.length +
      organizations.length +
      headings.length;
}

/// Comprehensive outcome of an AI analysis operation
class AiAnalysisResult {
  final AiAnalysisType type;
  final String textResult;
  final ExtractedDocumentInfo? extractedInfo;
  final bool isFromCloud;
  final String providerName;
  final int executionTimeMs;
  final String? warningMessage;

  const AiAnalysisResult({
    required this.type,
    required this.textResult,
    this.extractedInfo,
    required this.isFromCloud,
    required this.providerName,
    required this.executionTimeMs,
    this.warningMessage,
  });
}

/// Structured CV/Resume analysis feedback
class CvAnalysisResult {
  final int overallScore; // 0 to 100
  final List<String> foundSections;
  final List<String> missingSections;
  final int actionVerbCount;
  final List<String> actionVerbsUsed;
  final List<String> suggestions;
  final String summaryText;

  const CvAnalysisResult({
    required this.overallScore,
    required this.foundSections,
    required this.missingSections,
    required this.actionVerbCount,
    required this.actionVerbsUsed,
    required this.suggestions,
    required this.summaryText,
  });
}

/// Dual-engine AI Document Intelligence Service:
/// 1. Local Smart NLP Engine (100% offline, zero secret keys, private)
/// 2. Cloud AI Provider (Gemini API via user-provided API key)
class AiDocumentService {
  AiDocumentService._internal();
  static final AiDocumentService instance = AiDocumentService._internal();
  factory AiDocumentService() => instance;

  static const Set<String> _stopWords = {
    'a', 'about', 'above', 'after', 'again', 'against', 'all', 'am', 'an',
    'and', 'any', 'are', 'aren\'t', 'as', 'at', 'be', 'because', 'been',
    'before', 'being', 'below', 'between', 'both', 'but', 'by', 'can',
    'cannot', 'could', 'couldn\'t', 'did', 'didn\'t', 'do', 'does', 'doesn\'t',
    'doing', 'don\'t', 'down', 'during', 'each', 'few', 'for', 'from',
    'further', 'had', 'hadn\'t', 'has', 'hasn\'t', 'have', 'haven\'t', 'having',
    'he', 'he\'d', 'he\'ll', 'he\'s', 'her', 'here', 'here\'s', 'hers',
    'herself', 'him', 'himself', 'his', 'how', 'how\'s', 'i', 'i\'d', 'i\'ll',
    'i\'m', 'i\'ve', 'if', 'in', 'into', 'is', 'isn\'t', 'it', 'it\'s', 'its',
    'itself', 'let\'s', 'me', 'more', 'most', 'mustn\'t', 'my', 'myself',
    'no', 'nor', 'not', 'of', 'off', 'on', 'once', 'only', 'or', 'other',
    'ought', 'our', 'ours', 'ourselves', 'out', 'over', 'own', 'same',
    'shan\'t', 'she', 'she\'d', 'she\'ll', 'she\'s', 'should', 'shouldn\'t',
    'so', 'some', 'such', 'than', 'that', 'that\'s', 'the', 'their', 'theirs',
    'them', 'themselves', 'then', 'there', 'there\'s', 'these', 'they',
    'they\'d', 'they\'ll', 'they\'re', 'they\'ve', 'this', 'those', 'through',
    'to', 'too', 'under', 'until', 'up', 'very', 'was', 'wasn\'t', 'we',
    'we\'d', 'we\'ll', 'we\'re', 'we\'ve', 'were', 'weren\'t', 'what',
    'what\'s', 'when', 'when\'s', 'where', 'where\'s', 'which', 'while',
    'who', 'who\'s', 'whom', 'why', 'why\'s', 'with', 'won\'t', 'would',
    'wouldn\'t', 'you', 'you\'d', 'you\'ll', 'you\'re', 'you\'ve', 'your',
    'yours', 'yourself', 'yourselves', 'also', 'will', 'just',
  };

  static const List<String> _commonActionVerbs = [
    'accelerated', 'achieved', 'administered', 'analyzed', 'architected',
    'assembled', 'automated', 'built', 'championed', 'collaborated',
    'completed', 'conducted', 'configured', 'constructed', 'coordinated',
    'created', 'decreased', 'delivered', 'deployed', 'designed', 'developed',
    'directed', 'documented', 'engineered', 'enhanced', 'established',
    'evaluated', 'executed', 'expanded', 'expedited', 'facilitated',
    'formulated', 'generated', 'guided', 'headed', 'identified', 'implemented',
    'improved', 'increased', 'initiated', 'inspected', 'instituted',
    'instructed', 'integrated', 'invented', 'launched', 'led', 'maintained',
    'managed', 'marketed', 'maximized', 'mentored', 'minimized', 'modernized',
    'negotiated', 'operated', 'optimized', 'orchestrated', 'organized',
    'overhauled', 'oversaw', 'performed', 'pioneered', 'planned', 'prepared',
    'produced', 'programmed', 'promoted', 'published', 're-engineered',
    'recommended', 'reconciled', 'recruited', 'redesigned', 'reduced',
    'refactored', 'reorganized', 'researched', 'resolved', 'restructured',
    'reviewed', 'revamped', 'revitalized', 'saved', 'scheduled', 'secured',
    'simplified', 'spearheaded', 'standardized', 'streamlined', 'strengthened',
    'structured', 'supervised', 'surpassed', 'trained', 'transformed',
    'unified', 'upgraded', 'validated',
  ];

  // ===========================================================================
  // Public Analysis Dispatcher
  // ===========================================================================

  /// Executes requested AI analysis on the document text.
  /// Seamlessly utilizes Cloud AI if user provided a key and selected cloud mode;
  /// otherwise runs the high-performance local offline NLP engine.
  Future<AiAnalysisResult> processDocument({
    required String text,
    required AiAnalysisType type,
    String? userQuestion,
    bool forceLocal = false,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      return AiAnalysisResult(
        type: type,
        textResult: 'Document is empty. Please provide a document with readable text.',
        isFromCloud: false,
        providerName: 'Local NLP Engine',
        executionTimeMs: 0,
      );
    }

    final stopwatch = Stopwatch()..start();

    // Check Cloud AI eligibility
    final apiKey = await SettingsService.instance.getGeminiApiKey();
    final preferredProvider = await SettingsService.instance.getAiProvider();
    final canUseCloud = !forceLocal &&
        preferredProvider == 'gemini' &&
        apiKey != null &&
        apiKey.trim().isNotEmpty;

    if (canUseCloud) {
      try {
        final cloudResult = await _queryGeminiApi(
          apiKey: apiKey.trim(),
          documentText: cleanText,
          type: type,
          userQuestion: userQuestion,
        );
        stopwatch.stop();
        return AiAnalysisResult(
          type: type,
          textResult: cloudResult,
          extractedInfo: type == AiAnalysisType.extractInfo
              ? extractEntities(cleanText)
              : null,
          isFromCloud: true,
          providerName: 'Google Gemini (Cloud)',
          executionTimeMs: stopwatch.elapsedMilliseconds,
        );
      } catch (e) {
        debugPrint('Cloud AI request failed, falling back to Local NLP: $e');
        // Fallback gracefully to Local NLP
        final localRes = _processLocal(cleanText, type, userQuestion);
        stopwatch.stop();
        return AiAnalysisResult(
          type: type,
          textResult: localRes.textResult,
          extractedInfo: localRes.extractedInfo,
          isFromCloud: false,
          providerName: 'Local NLP Engine (Fallback)',
          executionTimeMs: stopwatch.elapsedMilliseconds,
          warningMessage:
              'Cloud AI connection failed ($e). Displaying locally processed results instead.',
        );
      }
    }

    // Default: Local NLP Engine
    final localRes = _processLocal(cleanText, type, userQuestion);
    stopwatch.stop();
    return AiAnalysisResult(
      type: type,
      textResult: localRes.textResult,
      extractedInfo: localRes.extractedInfo,
      isFromCloud: false,
      providerName: 'Local Smart NLP (On-Device)',
      executionTimeMs: stopwatch.elapsedMilliseconds,
    );
  }

  // ===========================================================================
  // Local NLP Engine (Offline, Rule-Based, Statistical)
  // ===========================================================================

  _LocalEngineOutcome _processLocal(
    String text,
    AiAnalysisType type,
    String? userQuestion,
  ) {
    switch (type) {
      case AiAnalysisType.summarize:
        return _LocalEngineOutcome(textResult: summarizeDocument(text));

      case AiAnalysisType.keyPoints:
        return _LocalEngineOutcome(textResult: extractKeyPoints(text));

      case AiAnalysisType.explain:
        return _LocalEngineOutcome(textResult: explainDocument(text));

      case AiAnalysisType.extractInfo:
        final info = extractEntities(text);
        return _LocalEngineOutcome(
          textResult: _formatExtractedInfo(info),
          extractedInfo: info,
        );

      case AiAnalysisType.studyNotes:
        return _LocalEngineOutcome(textResult: generateStudyNotes(text));

      case AiAnalysisType.askQuestion:
        return _LocalEngineOutcome(
          textResult: askAboutDocument(
            text,
            userQuestion ?? 'What is this document about?',
          ),
        );

      case AiAnalysisType.cvResume:
        final cv = analyzeCvResume(text);
        return _LocalEngineOutcome(textResult: cv.summaryText);
    }
  }

  /// 1. Summarize Document: Frequency-weighted extractive summarization
  String summarizeDocument(String text) {
    final sentences = _splitSentences(text);
    if (sentences.isEmpty) return 'No coherent sentences found to summarize.';
    if (sentences.length <= 3) {
      return sentences.join(' ');
    }

    final wordFreq = _computeWordFrequencies(text);
    final scoredSentences = <MapEntry<int, double>>[];

    for (int i = 0; i < sentences.length; i++) {
      final s = sentences[i];
      final words = _tokenize(s);
      if (words.isEmpty) continue;

      double score = 0;
      for (final w in words) {
        score += wordFreq[w] ?? 0;
      }

      // Normalization by sentence length (optimal: 12-25 words)
      final lengthFactor = (words.length >= 8 && words.length <= 35) ? 1.2 : 0.8;
      // Positional boost: intro and conclusion sentences carry higher weight
      final positionFactor = (i == 0 || i == sentences.length - 1) ? 1.3 : 1.0;

      final normalizedScore = (score / words.length) * lengthFactor * positionFactor;
      scoredSentences.add(MapEntry(i, normalizedScore));
    }

    // Sort by score and take top ~25% or 3 to 6 sentences
    scoredSentences.sort((a, b) => b.value.compareTo(a.value));
    final int targetCount = min(max(3, (sentences.length * 0.28).round()), 6);
    final topIndices = scoredSentences
        .take(targetCount)
        .map((e) => e.key)
        .toList()
      ..sort(); // Keep original chronological flow

    final summarySentences = topIndices.map((idx) => sentences[idx]).toList();
    final buffer = StringBuffer();
    buffer.writeln('### Executive Summary\n');
    buffer.writeln(summarySentences.join(' '));
    buffer.writeln('\n\n---');
    buffer.writeln(
      '_Generated by On-Device Smart NLP Engine • ${sentences.length} source sentences condensed to $targetCount key statements._',
    );
    return buffer.toString();
  }

  /// 2. Key Points: Extracts salient bullet takeaways
  String extractKeyPoints(String text) {
    final sentences = _splitSentences(text);
    if (sentences.isEmpty) return 'No bullet points could be extracted.';

    final wordFreq = _computeWordFrequencies(text);
    final scored = <MapEntry<String, double>>[];

    for (final s in sentences) {
      final words = _tokenize(s);
      if (words.length < 5) continue; // Skip trivial fragments

      double score = 0;
      for (final w in words) {
        score += wordFreq[w] ?? 0;
      }
      final lengthNorm = score / sqrt(words.length);
      scored.add(MapEntry(s, lengthNorm));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    final keyCount = min(max(4, (sentences.length * 0.25).round()), 8);
    final topPoints = scored.take(keyCount).map((e) => e.key).toList();

    final buffer = StringBuffer();
    buffer.writeln('### Key Takeaways & Core Points\n');
    for (int i = 0; i < topPoints.length; i++) {
      buffer.writeln('• **Point ${i + 1}**: ${topPoints[i]}');
    }
    buffer.writeln('\n---');
    buffer.writeln('_Extracted based on term salience and predicate prominence._');
    return buffer.toString();
  }

  /// 3. Explain Document: Synthesizes simplified plain language and readability score
  String explainDocument(String text) {
    final sentences = _splitSentences(text);
    final words = _tokenize(text);
    final totalWords = words.length;
    final totalSentences = max(1, sentences.length);

    // Readability computation (Flesch-Kincaid grade level approximation)
    int syllables = 0;
    int complexWordsCount = 0;
    final complexWordsList = <String>{};

    for (final w in words) {
      final syl = _countSyllables(w);
      syllables += syl;
      if (syl >= 3 && !_stopWords.contains(w)) {
        complexWordsCount++;
        if (complexWordsList.length < 8) complexWordsList.add(w);
      }
    }

    final double avgSentenceLength = totalWords / totalSentences;
    final double avgSyllablesPerWord = syllables / max(1, totalWords);
    final double readingEase =
        206.835 - (1.015 * avgSentenceLength) - (84.6 * avgSyllablesPerWord);

    String readabilityLevel;
    if (readingEase >= 80) {
      readabilityLevel = 'Very Easy (6th grade level)';
    } else if (readingEase >= 60) {
      readabilityLevel = 'Standard (High school level)';
    } else if (readingEase >= 40) {
      readabilityLevel = 'Fairly Difficult (College level)';
    } else {
      readabilityLevel = 'Complex / Technical (Academic / Professional)';
    }

    final buffer = StringBuffer();
    buffer.writeln('### Plain-English Document Explanation\n');
    buffer.writeln(
      '**Readability Rating**: $readabilityLevel (Score: ${readingEase.clamp(0, 100).toStringAsFixed(1)}/100)\n',
    );

    buffer.writeln('#### What this document is communicating:');
    final summary = summarizeDocument(text)
        .replaceAll('### Executive Summary\n\n', '')
        .replaceAll(RegExp(r'\n---[\s\S]*$'), '');
    buffer.writeln(summary);

    buffer.writeln('\n#### Key Vocabulary & Complex Terms:');
    if (complexWordsList.isNotEmpty) {
      for (final term in complexWordsList) {
        buffer.writeln(
          '• **${term[0].toUpperCase()}${term.substring(1)}**: High-salience domain terminology used in context.',
        );
      }
    } else {
      buffer.writeln('• This document uses accessible, straightforward everyday terminology.');
    }

    buffer.writeln('\n#### Structural Breakdown:');
    buffer.writeln('• **Word Count**: $totalWords words across $totalSentences sentences');
    buffer.writeln(
      '• **Average Sentence Complexity**: ${avgSentenceLength.toStringAsFixed(1)} words per sentence',
    );
    buffer.writeln(
      '• **Technical Density**: ${(complexWordsCount / max(1, totalWords) * 100).toStringAsFixed(1)}% polysyllabic vocabulary',
    );

    return buffer.toString();
  }

  /// 4. Extract Important Information: Regex & Entity Extraction
  ExtractedDocumentInfo extractEntities(String text) {
    // 1. Dates: formats like MM/DD/YYYY, DD-MM-YYYY, YYYY-MM-DD, Jan 15 2026, 15th January 2026
    final dateRegex = RegExp(
      r'\b(?:\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2}|(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember))\s+\d{1,2}(?:st|nd|rd|th)?,?\s+\d{4}|\d{1,2}(?:st|nd|rd|th)?\s+(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember))\s+\d{4})\b',
      caseSensitive: false,
    );
    final dates = dateRegex
        .allMatches(text)
        .map((m) => m.group(0)!.trim())
        .toSet()
        .toList();

    // 2. Financial Amounts & Metrics: $500, €1,200.50, £40, 15%, 250 USD, Rs. 50,000
    final amountRegex = RegExp(
      r'(?:[\$€£¥₹]|Rs\.?|USD|EUR|GBP|PKR)\s*[\d,]+(?:\.\d{1,2})?|\b[\d,]+(?:\.\d{1,2})?\s*(?:percent|%|USD|EUR|dollars|euros|pounds|rupees)\b',
      caseSensitive: false,
    );
    final amounts = amountRegex
        .allMatches(text)
        .map((m) => m.group(0)!.trim())
        .toSet()
        .toList();

    // 3. Deadlines & Action Items
    final deadlineSentences = <String>{};
    final sentences = _splitSentences(text);
    final deadlineTerms = RegExp(
      r'\b(?:due date|deadline|expires|expiry|submit\s+by|valid\s+until|by\s+date|action\s+required|must\s+be\s+completed)\b',
      caseSensitive: false,
    );
    for (final s in sentences) {
      if (deadlineTerms.hasMatch(s)) {
        deadlineSentences.add(s.trim());
      }
    }

    // 4. Organizations & Corporate Entities
    final orgRegex = RegExp(
      r'\b([A-Z][A-Za-z0-9&.\s]{1,25}\s+(?:Inc\.?|Corp\.?|LLC|Ltd\.?|Company|Co\.?|Bank|University|College|Hospital|Foundation|Association|Department|Institute|Services|Technologies|Group|Solutions))\b',
    );
    final organizations = orgRegex
        .allMatches(text)
        .map((m) => m.group(1)!.trim())
        .toSet()
        .toList();

    // 5. Names (Honorifics & Proper Nouns)
    final nameRegex = RegExp(
      r'\b(?:Mr\.|Mrs\.|Ms\.|Dr\.|Prof\.|Judge|President|Director|Officer)\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?\b',
    );
    final names = nameRegex
        .allMatches(text)
        .map((m) => m.group(0)!.trim())
        .toSet()
        .toList();

    // 6. Headings & Major Structural Sections
    final headings = <String>[];
    final lines = text.split('\n');
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      // Heading patterns: All-caps short line, or numbered sections (e.g. 1. Introduction)
      if ((line == line.toUpperCase() && line.length > 3 && line.length < 45 && RegExp(r'[A-Z]').hasMatch(line)) ||
          RegExp(r'^(?:Chapter|Section|\d+\.)\s+[A-Z]', caseSensitive: false).hasMatch(line)) {
        if (!headings.contains(line)) headings.add(line);
      }
    }

    return ExtractedDocumentInfo(
      names: names,
      dates: dates,
      amounts: amounts,
      deadlines: deadlineSentences.toList(),
      organizations: organizations,
      headings: headings,
    );
  }

  String _formatExtractedInfo(ExtractedDocumentInfo info) {
    final buffer = StringBuffer();
    buffer.writeln('### Extracted Document Entities & Information\n');

    if (info.isEmpty) {
      buffer.writeln(
        'No structured entities (names, dates, financial amounts, deadlines) were detected in this document.',
      );
      return buffer.toString();
    }

    if (info.dates.isNotEmpty) {
      buffer.writeln('#### 📅 Dates & Timelines');
      for (final d in info.dates) {
        buffer.writeln('• $d');
      }
      buffer.writeln();
    }

    if (info.amounts.isNotEmpty) {
      buffer.writeln('#### 💰 Financial Amounts & Metrics');
      for (final a in info.amounts) {
        buffer.writeln('• $a');
      }
      buffer.writeln();
    }

    if (info.deadlines.isNotEmpty) {
      buffer.writeln('#### ⏰ Deadlines & Action Items');
      for (final d in info.deadlines) {
        buffer.writeln('• $d');
      }
      buffer.writeln();
    }

    if (info.names.isNotEmpty) {
      buffer.writeln('#### 👤 People & Names');
      for (final n in info.names) {
        buffer.writeln('• $n');
      }
      buffer.writeln();
    }

    if (info.organizations.isNotEmpty) {
      buffer.writeln('#### 🏢 Organizations & Institutions');
      for (final o in info.organizations) {
        buffer.writeln('• $o');
      }
      buffer.writeln();
    }

    if (info.headings.isNotEmpty) {
      buffer.writeln('#### 📑 Document Headings & Sections');
      for (final h in info.headings) {
        buffer.writeln('• $h');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// 5. Study Notes: Synthesizes outline, definitions, and self-test review questions
  String generateStudyNotes(String text) {
    final wordFreq = _computeWordFrequencies(text);
    final sortedKeywords = wordFreq.keys.toList()
      ..sort((a, b) => (wordFreq[b] ?? 0).compareTo(wordFreq[a] ?? 0));

    final topKeywords = sortedKeywords.take(6).toList();

    final buffer = StringBuffer();
    buffer.writeln('### 📚 Structured Study Notes\n');

    buffer.writeln('#### I. Core Subject Topics');
    for (final kw in topKeywords) {
      buffer.writeln('• **${kw[0].toUpperCase()}${kw.substring(1)}** (Frequency: ${wordFreq[kw]} occurrences)');
    }
    buffer.writeln();

    buffer.writeln('#### II. Key Concept Summaries');
    final keyPoints = extractKeyPoints(text)
        .replaceAll('### Key Takeaways & Core Points\n\n', '')
        .replaceAll(RegExp(r'\n---[\s\S]*$'), '');
    buffer.writeln(keyPoints);
    buffer.writeln();

    buffer.writeln('#### III. Self-Check Review Questions');
    if (topKeywords.isNotEmpty) {
      buffer.writeln(
        '1. **Comprehension**: What is the primary role of **${topKeywords[0]}** as outlined in the text?',
      );
      if (topKeywords.length > 1) {
        buffer.writeln(
          '2. **Analysis**: How does the author connect **${topKeywords[0]}** with **${topKeywords[1]}**?',
        );
      }
      if (topKeywords.length > 2) {
        buffer.writeln(
          '3. **Application**: What are the key implications of **${topKeywords[2]}** presented in the findings?',
        );
      }
      buffer.writeln(
        '4. **Synthesis**: Based on the overall document context, what main conclusion can be drawn?',
      );
    } else {
      buffer.writeln('1. What is the author\'s main assertion in this text?');
      buffer.writeln('2. What supporting evidence is provided?');
    }

    buffer.writeln('\n---');
    buffer.writeln('_Synthesized for efficient study and memory retention._');
    return buffer.toString();
  }

  /// 6. Ask About This Document: Passage retrieval and contextual answer generation
  String askAboutDocument(String text, String question) {
    final qTokens = _tokenize(question).where((t) => !_stopWords.contains(t)).toSet();
    if (qTokens.isEmpty) {
      return 'Please specify a question containing key concepts to look for in the document.';
    }

    final sentences = _splitSentences(text);
    if (sentences.isEmpty) {
      return 'The document contains no readable text to answer your question.';
    }

    // Score sentences by token overlap and semantic matching
    final matchingPassages = <MapEntry<String, double>>[];
    for (final s in sentences) {
      final sTokens = _tokenize(s);
      if (sTokens.isEmpty) continue;

      int overlap = 0;
      for (final q in qTokens) {
        if (sTokens.contains(q)) {
          overlap += 2;
        } else if (q.length >= 4 &&
            sTokens.any((st) =>
                st.length >= 4 &&
                (st.startsWith(q.substring(0, min(q.length, 4))) ||
                    q.startsWith(st.substring(0, min(st.length, 4)))))) {
          overlap += 1;
        }
      }

      if (overlap > 0) {
        final score = overlap / sqrt(sTokens.length);
        matchingPassages.add(MapEntry(s, score));
      }
    }

    final buffer = StringBuffer();
    buffer.writeln('### 💬 Q&A Answer\n');
    buffer.writeln('**Question**: _"$question"_\n');

    if (matchingPassages.isEmpty) {
      buffer.writeln(
        'The provided document does not appear to contain explicit information addressing your query.\n',
      );
      buffer.writeln('**Key topics available in this document:**');
      final topWords = _computeWordFrequencies(text).keys.take(5).join(', ');
      buffer.writeln('• $topWords');
      return buffer.toString();
    }

    matchingPassages.sort((a, b) => b.value.compareTo(a.value));
    final topAnswers = matchingPassages.take(3).map((e) => e.key).toList();

    buffer.writeln('**Answer based on document text:**\n');
    buffer.writeln(topAnswers.join(' '));
    buffer.writeln('\n\n#### Direct Excerpts from Document:');
    for (int i = 0; i < topAnswers.length; i++) {
      buffer.writeln('• _"${topAnswers[i]}"_');
    }

    return buffer.toString();
  }

  /// 7. CV / Resume Assistance: ATS section detection, action verbs, and completeness
  CvAnalysisResult analyzeCvResume(String text) {
    final lower = text.toLowerCase();

    // Standard CV Sections
    final standardSections = {
      'Contact Information': RegExp(
        r'\b(?:email|phone|mobile|address|linkedin|github|portfolio|contact)\b',
      ),
      'Professional Summary': RegExp(
        r'\b(?:summary|profile|about me|objective|professional summary)\b',
      ),
      'Work Experience': RegExp(
        r'\b(?:experience|employment|work history|career history|positions held)\b',
      ),
      'Education': RegExp(
        r'\b(?:education|academic|degree|university|college|bachelor|master|phd|gpa)\b',
      ),
      'Skills': RegExp(
        r'\b(?:skills|competencies|technologies|tools|languages|expertise)\b',
      ),
      'Projects': RegExp(
        r'\b(?:projects|portfolio|initiatives|key projects)\b',
      ),
      'Certifications': RegExp(
        r'\b(?:certifications|certificates|licenses|accreditations)\b',
      ),
    };

    final foundSections = <String>[];
    final missingSections = <String>[];

    for (final entry in standardSections.entries) {
      if (entry.value.hasMatch(lower)) {
        foundSections.add(entry.key);
      } else {
        missingSections.add(entry.key);
      }
    }

    // Action Verb Analysis
    final tokens = _tokenize(text);
    final usedVerbs = <String>{};
    for (final token in tokens) {
      if (_commonActionVerbs.contains(token)) {
        usedVerbs.add(token);
      }
    }

    // Suggestions Generation
    final suggestions = <String>[];
    if (missingSections.contains('Professional Summary')) {
      suggestions.add(
        'Add a concise 3-4 sentence Professional Summary at the top highlighting your core value proposition.',
      );
    }
    if (missingSections.contains('Skills')) {
      suggestions.add(
        'Create a dedicated Skills section categorizing technical tools and domain proficiencies for ATS scanning.',
      );
    }
    if (missingSections.contains('Projects')) {
      suggestions.add(
        'Highlight 2-3 notable Projects with quantifiable impact and technologies used.',
      );
    }
    if (missingSections.contains('Certifications')) {
      suggestions.add(
        'List relevant professional Certifications or specialized course credentials.',
      );
    }
    if (usedVerbs.length < 5) {
      suggestions.add(
        'Enhance bullet points with impactful action verbs (e.g., "Spearheaded", "Optimized", "Architected", "Delivered") instead of passive phrases.',
      );
    }

    // Check for quantifiable metrics (percentages, numbers, dollar amounts)
    final hasMetrics = RegExp(r'\b(?:\d+%|\$\d+|\d+\+?\s*(?:users|clients|team members|revenue))\b')
        .hasMatch(text);
    if (!hasMetrics) {
      suggestions.add(
        'Quantify achievements with measurable metrics (e.g., "reduced latency by 35%", "managed a team of 8").',
      );
    }

    // Scoring Algorithm (0-100)
    int score = 30; // base score for having text
    score += (foundSections.length * 8); // up to 56 points for sections
    score += min(14, usedVerbs.length * 2); // up to 14 points for action verbs
    if (hasMetrics) score += 10;
    score = score.clamp(10, 100);

    final summaryBuffer = StringBuffer();
    summaryBuffer.writeln('### 📄 CV / Resume Assessment Report\n');
    summaryBuffer.writeln('**ATS Quality Rating**: **$score / 100**\n');

    summaryBuffer.writeln('#### ✅ Identified Sections:');
    if (foundSections.isNotEmpty) {
      for (final s in foundSections) {
        summaryBuffer.writeln('• $s');
      }
    } else {
      summaryBuffer.writeln('• No standard resume section headers were detected.');
    }
    summaryBuffer.writeln();

    if (missingSections.isNotEmpty) {
      summaryBuffer.writeln('#### ⚠️ Recommended Sections to Add:');
      for (final s in missingSections) {
        summaryBuffer.writeln('• $s');
      }
      summaryBuffer.writeln();
    }

    summaryBuffer.writeln('#### 🚀 Action Verb Strength:');
    summaryBuffer.writeln(
      '• Identified **${usedVerbs.length} unique action verbs**: ${usedVerbs.take(8).join(', ')}${usedVerbs.length > 8 ? '...' : ''}',
    );
    summaryBuffer.writeln();

    summaryBuffer.writeln('#### 💡 Concrete Actionable Suggestions:');
    if (suggestions.isNotEmpty) {
      for (final s in suggestions) {
        summaryBuffer.writeln('• $s');
      }
    } else {
      summaryBuffer.writeln('• Outstanding resume structure with comprehensive sections and strong impact!');
    }

    return CvAnalysisResult(
      overallScore: score,
      foundSections: foundSections,
      missingSections: missingSections,
      actionVerbCount: usedVerbs.length,
      actionVerbsUsed: usedVerbs.toList(),
      suggestions: suggestions,
      summaryText: summaryBuffer.toString(),
    );
  }

  // ===========================================================================
  // Cloud AI Integration (Google Gemini REST API)
  // ===========================================================================

  Future<String> _queryGeminiApi({
    required String apiKey,
    required String documentText,
    required AiAnalysisType type,
    String? userQuestion,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 12);

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
    );

    String systemInstruction;
    switch (type) {
      case AiAnalysisType.summarize:
        systemInstruction =
            'You are an expert document assistant. Provide a concise, clear, and structured executive summary of the following document.';
        break;
      case AiAnalysisType.keyPoints:
        systemInstruction =
            'You are an expert document assistant. Extract the most important key points and takeaways from the document as clear bullet points.';
        break;
      case AiAnalysisType.explain:
        systemInstruction =
            'You are an expert document assistant. Explain the following document in simple, plain everyday language so anyone can understand it.';
        break;
      case AiAnalysisType.extractInfo:
        systemInstruction =
            'Extract important entities from the document: Names, Dates, Deadlines, Amounts/Currencies, Organizations, and Main Headings. Group them cleanly.';
        break;
      case AiAnalysisType.studyNotes:
        systemInstruction =
            'Turn the following document into comprehensive, structured study notes with Core Concepts, Key Terms, Summary Outline, and 4 Self-Test Questions.';
        break;
      case AiAnalysisType.askQuestion:
        systemInstruction =
            'Answer the following user question specifically and accurately using ONLY the provided document text. Cite the relevant context.';
        break;
      case AiAnalysisType.cvResume:
        systemInstruction =
            'You are an expert resume reviewer and ATS specialist. Review this CV/Resume: identify strengths, missing sections, action verb usage, and provide actionable improvements.';
        break;
    }

    String prompt = '$systemInstruction\n\nDOCUMENT CONTENT:\n$documentText';
    if (type == AiAnalysisType.askQuestion && userQuestion != null) {
      prompt = '$prompt\n\nUSER QUESTION: $userQuestion';
    }

    final payload = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 1200,
      }
    };

    try {
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode(payload));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw HttpException(
          'Gemini API returned status ${response.statusCode}: $responseBody',
        );
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw const FormatException('No response candidates returned from Gemini.');
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        throw const FormatException('Empty content returned from Gemini.');
      }

      return parts[0]['text'] as String;
    } finally {
      client.close();
    }
  }

  // ===========================================================================
  // Document Saving Integration
  // ===========================================================================

  /// Saves any AI analysis result as a .txt document in Documents
  Future<DocumentsModel> saveAnalysisAsDocument({
    required String textContent,
    required AiAnalysisType type,
    String? originalDocName,
    Directory? outputDirectory,
  }) async {
    Directory saveDir;
    if (outputDirectory != null) {
      saveDir = outputDirectory;
    } else {
      try {
        saveDir = await getApplicationDocumentsDirectory().timeout(
          const Duration(seconds: 1),
        );
      } catch (_) {
        saveDir = Directory.systemTemp;
      }
    }

    if (!saveDir.existsSync()) {
      await saveDir.create(recursive: true);
    }

    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final base = originalDocName != null && originalDocName.isNotEmpty
        ? originalDocName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
        : 'Document';

    final fileName = '${base}_${type.shortLabel.replaceAll(' ', '_')}_$stamp.txt';
    final targetPath = '${saveDir.path}/$fileName';

    final file = File(targetPath);
    await file.writeAsString(textContent, flush: true);

    final docModel = DocumentsModel(
      name: fileName,
      path: file.path,
      type: 'txt',
      createdAt: DateTime.now(),
    );

    await DocumentsStorageService.instance.addDocument(docModel);
    return docModel;
  }

  // ===========================================================================
  // Utility & Tokenization Helpers
  // ===========================================================================

  List<String> _splitSentences(String text) {
    // Splits by sentence delimiters (. ! ?) while handling abbreviations
    final raw = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split(RegExp(r'(?<=[.!?])\s+(?=[A-Z0-9])'));

    final results = <String>[];
    for (final s in raw) {
      final trimmed = s.trim();
      if (trimmed.length > 5) {
        results.add(trimmed);
      }
    }
    return results;
  }

  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1)
        .toList();
  }

  Map<String, int> _computeWordFrequencies(String text) {
    final tokens = _tokenize(text);
    final freq = <String, int>{};
    for (final t in tokens) {
      if (_stopWords.contains(t) || t.length < 3) continue;
      freq[t] = (freq[t] ?? 0) + 1;
    }
    return freq;
  }

  int _countSyllables(String word) {
    final w = word.toLowerCase();
    if (w.length <= 3) return 1;
    final vowels = RegExp(r'[aeiouy]+');
    int count = vowels.allMatches(w).length;
    if (w.endsWith('e') && !w.endsWith('le')) {
      count = max(1, count - 1);
    }
    return max(1, count);
  }
}

class _LocalEngineOutcome {
  final String textResult;
  final ExtractedDocumentInfo? extractedInfo;

  const _LocalEngineOutcome({
    required this.textResult,
    this.extractedInfo,
  });
}
