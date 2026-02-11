import 'dart:convert';

import '../../domain/entities/file_node.dart';

class FileContentModel {
  const FileContentModel({
    required this.path,
    required this.content,
    required this.isBinary,
    this.mimeType,
  });

  final String path;
  final String content;
  final bool isBinary;
  final String? mimeType;

  factory FileContentModel.fromResponse(
    dynamic responseData, {
    required String path,
  }) {
    if (responseData is String) {
      return FileContentModel(
        path: path,
        content: responseData,
        isBinary: false,
      );
    }

    if (responseData is List<int>) {
      return FileContentModel(
        path: path,
        content: utf8.decode(responseData, allowMalformed: true),
        isBinary: false,
      );
    }

    if (responseData is! Map) {
      return FileContentModel(path: path, content: '', isBinary: false);
    }

    final json = Map<String, dynamic>.from(responseData);
    final type = (json['type'] as String?)?.trim().toLowerCase();
    final binaryFlag = json['binary'] == true;
    final mimeType = (json['mime'] as String?) ?? (json['mimeType'] as String?);
    final encoding = (json['encoding'] as String?)?.trim().toLowerCase();
    final isBinary = binaryFlag || type == 'binary' || encoding == 'base64';
    if (isBinary) {
      return FileContentModel(
        path: path,
        content: '',
        isBinary: true,
        mimeType: mimeType,
      );
    }

    final dynamic rawContent =
        json['content'] ??
        json['text'] ??
        json['value'] ??
        json['data'] ??
        json['body'];
    if (rawContent is String) {
      return FileContentModel(
        path: path,
        content: rawContent,
        isBinary: false,
        mimeType: mimeType,
      );
    }
    if (rawContent is List<int>) {
      return FileContentModel(
        path: path,
        content: utf8.decode(rawContent, allowMalformed: true),
        isBinary: false,
        mimeType: mimeType,
      );
    }
    return FileContentModel(
      path: path,
      content: '',
      isBinary: false,
      mimeType: mimeType,
    );
  }

  FileContent toDomain() {
    return FileContent(
      path: path,
      content: content,
      isBinary: isBinary,
      mimeType: mimeType,
    );
  }
}
