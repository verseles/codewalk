import '../../domain/entities/project.dart';

/// Technical comment translated to English.
class ProjectModel {
  final String id;
  final String name;
  final String path;
  final String createdAt;
  final String? updatedAt;

  const ProjectModel({
    required this.id,
    required this.name,
    required this.path,
    required this.createdAt,
    this.updatedAt,
  });

  /// Technical comment translated to English.
  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  /// Technical comment translated to English.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  /// Technical comment translated to English.
  Project toDomain() {
    return Project(
      id: id,
      name: name,
      path: path,
      createdAt: DateTime.parse(createdAt),
      updatedAt: updatedAt != null ? DateTime.parse(updatedAt!) : null,
    );
  }

  /// Technical comment translated to English.
  factory ProjectModel.fromDomain(Project project) {
    return ProjectModel(
      id: project.id,
      name: project.name,
      path: project.path,
      createdAt: project.createdAt.toIso8601String(),
      updatedAt: project.updatedAt?.toIso8601String(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProjectModel &&
        other.id == id &&
        other.name == name &&
        other.path == path &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        path.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }

  @override
  String toString() {
    return 'ProjectModel(id: $id, name: $name, path: $path, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}

/// Technical comment translated to English.
class ProjectsResponseModel {
  final List<ProjectModel> projects;

  const ProjectsResponseModel({required this.projects});

  /// Technical comment translated to English.
  factory ProjectsResponseModel.fromJson(dynamic json) {
    if (json is List) {
      return ProjectsResponseModel(
        projects: json
            .map((item) => ProjectModel.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    } else if (json is Map<String, dynamic> && json.containsKey('projects')) {
      return ProjectsResponseModel(
        projects: (json['projects'] as List)
            .map((item) => ProjectModel.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    } else {
      throw FormatException('Invalid JSON format for ProjectsResponseModel');
    }
  }

  /// Technical comment translated to English.
  dynamic toJson() {
    return projects.map((project) => project.toJson()).toList();
  }

  /// Technical comment translated to English.
  List<Project> toDomain() {
    return projects.map((project) => project.toDomain()).toList();
  }
}
