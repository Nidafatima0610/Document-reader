import 'dart:ui';

/// Document enhancement filter modes
enum DocumentFilterType {
  original,
  grayscale,
  blackAndWhite,
  enhanced,
}

extension DocumentFilterTypeExtension on DocumentFilterType {
  String get label {
    switch (this) {
      case DocumentFilterType.original:
        return 'Original';
      case DocumentFilterType.grayscale:
        return 'Grayscale';
      case DocumentFilterType.blackAndWhite:
        return 'B&W';
      case DocumentFilterType.enhanced:
        return 'Enhanced';
    }
  }
}

/// Represents a single page within a multi-page scanning session
class ScannedPageModel {
  final String id;
  final String originalImagePath;
  final String processedImagePath;
  final DocumentFilterType currentFilter;
  final int rotationDegrees; // 0, 90, 180, 270
  final Rect? normalizedCropRect;

  const ScannedPageModel({
    required this.id,
    required this.originalImagePath,
    required this.processedImagePath,
    this.currentFilter = DocumentFilterType.original,
    this.rotationDegrees = 0,
    this.normalizedCropRect,
  });

  ScannedPageModel copyWith({
    String? id,
    String? originalImagePath,
    String? processedImagePath,
    DocumentFilterType? currentFilter,
    int? rotationDegrees,
    Rect? normalizedCropRect,
  }) {
    return ScannedPageModel(
      id: id ?? this.id,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      processedImagePath: processedImagePath ?? this.processedImagePath,
      currentFilter: currentFilter ?? this.currentFilter,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      normalizedCropRect: normalizedCropRect ?? this.normalizedCropRect,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScannedPageModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
