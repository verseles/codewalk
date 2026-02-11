import 'package:equatable/equatable.dart';

enum FileNodeType { file, directory, unknown }

class FileNode extends Equatable {
  const FileNode({required this.path, required this.name, required this.type});

  final String path;
  final String name;
  final FileNodeType type;

  bool get isDirectory => type == FileNodeType.directory;
  bool get isFile => type == FileNodeType.file;

  @override
  List<Object?> get props => [path, name, type];
}

class FileContent extends Equatable {
  const FileContent({
    required this.path,
    required this.content,
    required this.isBinary,
    this.mimeType,
  });

  final String path;
  final String content;
  final bool isBinary;
  final String? mimeType;

  bool get isEmpty => !isBinary && content.isEmpty;

  @override
  List<Object?> get props => [path, content, isBinary, mimeType];
}
