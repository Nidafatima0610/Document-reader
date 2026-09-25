// ignore_for_file: public_member_api_docs, sort_constructors_first

class DocumentsModel {
  final String name;
  final String path;
  final String type;
  final DateTime createdAt;
  final bool isFavorite;
  final DateTime? lastOpenedAt;

  DocumentsModel({
    required this.name,
    required this.path,
    required this.type,
    required this.createdAt,
    this.isFavorite = false,
    this.lastOpenedAt,
  });

  String get id => path.isNotEmpty ? path : name;

  DocumentsModel copyWith({
    String? name,
    String? path,
    String? type,
    DateTime? createdAt,
    bool? isFavorite,
    DateTime? lastOpenedAt,
  }) {
    return DocumentsModel(
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'path': path,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'isFavorite': isFavorite,
      'lastOpenedAt': lastOpenedAt?.toIso8601String(),
    };
  }

  factory DocumentsModel.fromMap(Map<String, dynamic> map) {
    return DocumentsModel(
      name: map['name'] as String,
      path: map['path'] as String,
      type: map['type'] as String,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      isFavorite: map['isFavorite'] as bool? ?? false,
      lastOpenedAt: map['lastOpenedAt'] != null
          ? DateTime.parse(map['lastOpenedAt'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DocumentsModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
