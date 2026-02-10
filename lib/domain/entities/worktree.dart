class Worktree {
  const Worktree({
    required this.id,
    required this.name,
    required this.directory,
    this.projectId,
    this.active = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final String directory;
  final String? projectId;
  final bool active;
  final DateTime? createdAt;

  Worktree copyWith({
    String? id,
    String? name,
    String? directory,
    String? projectId,
    bool? active,
    DateTime? createdAt,
  }) {
    return Worktree(
      id: id ?? this.id,
      name: name ?? this.name,
      directory: directory ?? this.directory,
      projectId: projectId ?? this.projectId,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Worktree &&
        other.id == id &&
        other.name == name &&
        other.directory == directory &&
        other.projectId == projectId &&
        other.active == active &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        directory.hashCode ^
        projectId.hashCode ^
        active.hashCode ^
        createdAt.hashCode;
  }
}
