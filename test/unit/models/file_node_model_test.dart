import 'package:codewalk/data/models/file_node_model.dart';
import 'package:codewalk/domain/entities/file_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileNodeModel', () {
    test('keeps rooted-relative path without forcing a leading slash', () {
      final node = FileNodeModel.fromJson(<String, dynamic>{
        'path': 'lib/main.dart',
        'name': 'main.dart',
        'type': 'file',
      }, parentPath: '.');

      expect(node.path, 'lib/main.dart');
      expect(node.type, FileNodeType.file);
    });

    test('joins basename with parent path when server returns only name', () {
      final node = FileNodeModel.fromJson(<String, dynamic>{
        'path': 'main.dart',
        'name': 'main.dart',
        'type': 'file',
      }, parentPath: 'lib');

      expect(node.path, 'lib/main.dart');
      expect(node.type, FileNodeType.file);
    });

    test('avoids duplicated prefix when path already includes directories', () {
      final node = FileNodeModel.fromJson(<String, dynamic>{
        'path': 'lib/main.dart',
        'name': 'main.dart',
        'type': 'file',
      }, parentPath: '/repo/a/lib');

      expect(node.path, 'lib/main.dart');
      expect(node.type, FileNodeType.file);
    });
  });
}
