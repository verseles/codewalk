import 'package:flutter_test/flutter_test.dart';

import 'package:codewalk/data/models/project_model.dart';

void main() {
  group('ProjectModel', () {
    test('parses modern project payload using worktree path', () {
      final model = ProjectModel.fromJson(<String, dynamic>{
        'id': '043ce9d788338bd5576d7cbd12032d68e1829a02',
        'worktree': '/home/helio/Dropbox/WORK/showdown',
        'vcs': 'git',
        'time': <String, dynamic>{
          'created': 1766965018756,
          'updated': 1767734436172,
        },
      });

      expect(model.id, '043ce9d788338bd5576d7cbd12032d68e1829a02');
      expect(model.path, '/home/helio/Dropbox/WORK/showdown');
      expect(model.name, 'showdown');
      expect(
        DateTime.parse(model.createdAt).millisecondsSinceEpoch,
        1766965018756,
      );
      expect(
        DateTime.parse(model.updatedAt!).millisecondsSinceEpoch,
        1767734436172,
      );
    });

    test('parses global payload as Global root context', () {
      final model = ProjectModel.fromJson(<String, dynamic>{
        'id': 'global',
        'worktree': '/',
        'time': <String, dynamic>{
          'created': 1766957938904,
          'updated': 1770663087908,
        },
      });

      expect(model.id, 'global');
      expect(model.path, '/');
      expect(model.name, 'Global');
    });

    test('parses nested path map when present', () {
      final model = ProjectModel.fromJson(<String, dynamic>{
        'id': 'proj_nested',
        'name': 'Nested',
        'path': <String, dynamic>{
          'root': '/workspace/project',
          'cwd': '/workspace/project',
        },
      });

      expect(model.id, 'proj_nested');
      expect(model.name, 'Nested');
      expect(model.path, '/workspace/project');
    });
  });
}
