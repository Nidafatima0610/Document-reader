import 'package:flutter/material.dart';

/// Categories grouping tools into logical sections
enum ToolCategory {
  create,
  convert,
  managePdf;

  String get displayName {
    switch (this) {
      case ToolCategory.create:
        return 'Create';
      case ToolCategory.convert:
        return 'Convert';
      case ToolCategory.managePdf:
        return 'Manage PDF';
    }
  }

  String get description {
    switch (this) {
      case ToolCategory.create:
        return 'Generate fresh documents from images and text';
      case ToolCategory.convert:
        return 'Transform files between PDF, Word, images, and text';
      case ToolCategory.managePdf:
        return 'Merge, split, compress, and organize PDF pages';
    }
  }

  IconData get icon {
    switch (this) {
      case ToolCategory.create:
        return Icons.note_add_outlined;
      case ToolCategory.convert:
        return Icons.swap_horiz_rounded;
      case ToolCategory.managePdf:
        return Icons.picture_as_pdf_outlined;
    }
  }
}

/// Operational status of a tool
enum ToolStatus {
  available,
  inDevelopment,
  planned;

  String get badgeLabel {
    switch (this) {
      case ToolStatus.available:
        return 'Ready';
      case ToolStatus.inDevelopment:
        return 'In Progress';
      case ToolStatus.planned:
        return 'Planned';
    }
  }
}

/// Definition model for each document utility tool
class ToolItemModel {
  final String id;
  final String title;
  final String description;
  final ToolCategory category;
  final IconData icon;
  final Color accentColor;
  final ToolStatus status;
  final List<String> supportedInputFormats;
  final String outputFormat;
  final List<String> features;
  final WidgetBuilder? routeBuilder;

  const ToolItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.accentColor,
    this.status = ToolStatus.planned,
    this.supportedInputFormats = const [],
    required this.outputFormat,
    this.features = const [],
    this.routeBuilder,
  });

  bool get isAvailable => status == ToolStatus.available;
}
