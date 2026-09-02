// ignore_for_file: public_member_api_docs, sort_constructors_first

class DocumentsModel {
  final String name;
  final String path;
  final String type;
  final DateTime createdAt;
  DocumentsModel({required this.name, required this.path, required this.type,required this.createdAt});

  Map<String, dynamic> toMap() {
    return {'name': name, 'path': path, 'type': type,'createdAt' : createdAt.toIso8601String()};
  }

  factory DocumentsModel.fromMap(Map<String, dynamic> map) {
    return DocumentsModel(
      name: map['name'] as String,
      path: map['path'] as String,
      type: map['type'] as String,
      createdAt:map['createdAt'] != null
      ? DateTime.parse(map['createdAt'] as String)
      : DateTime.now(),
    );
  }
}
