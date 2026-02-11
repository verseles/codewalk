import '../models/project_model.dart';
import '../models/file_content_model.dart';
import '../models/file_node_model.dart';
import '../models/worktree_model.dart';

/// Technical comment translated to English.
abstract class ProjectRemoteDataSource {
  /// Technical comment translated to English.
  Future<ProjectsResponseModel> getProjects();

  /// Technical comment translated to English.
  Future<ProjectModel> getCurrentProject({String? directory});

  /// Technical comment translated to English.
  Future<ProjectModel> getProject(String projectId);

  /// Technical comment translated to English.
  Future<List<WorktreeModel>> getWorktrees({String? directory});

  /// Technical comment translated to English.
  Future<WorktreeModel> createWorktree(String name, {String? directory});

  /// Technical comment translated to English.
  Future<void> resetWorktree(String worktreeId, {String? directory});

  /// Technical comment translated to English.
  Future<void> deleteWorktree(String worktreeId, {String? directory});

  /// Technical comment translated to English.
  Future<List<String>> listDirectories(String directory);

  /// Technical comment translated to English.
  Future<bool> isGitDirectory(String directory);

  /// List file/directory nodes from a path in current context.
  Future<List<FileNodeModel>> listFiles({
    String? directory,
    required String path,
  });

  /// Search files by query in current context.
  Future<List<FileNodeModel>> findFiles({
    String? directory,
    required String query,
    int limit,
  });

  /// Read file content by path.
  Future<FileContentModel> readFileContent({
    String? directory,
    required String path,
  });
}

/// Technical comment translated to English.
class ProjectRemoteDataSourceImpl implements ProjectRemoteDataSource {
  final dynamic dio;

  ProjectRemoteDataSourceImpl({required this.dio});

  @override
  Future<ProjectsResponseModel> getProjects() async {
    final response = await dio.get('/project');
    return ProjectsResponseModel.fromJson(response.data);
  }

  @override
  Future<ProjectModel> getCurrentProject({String? directory}) async {
    final queryParams = directory != null
        ? {'directory': directory}
        : <String, dynamic>{};
    final response = await dio.get(
      '/project/current',
      queryParameters: queryParams,
    );
    return ProjectModel.fromJson(response.data);
  }

  @override
  Future<ProjectModel> getProject(String projectId) async {
    final projectsResponse = await dio.get('/project');
    final projects = ProjectsResponseModel.fromJson(projectsResponse.data);
    final matched = projects.projects
        .where((project) => project.id == projectId)
        .firstOrNull;
    if (matched != null) {
      return matched;
    }

    // Fallback for servers without stable project list IDs.
    final response = await dio.get('/project/current');
    return ProjectModel.fromJson(response.data);
  }

  @override
  Future<List<WorktreeModel>> getWorktrees({String? directory}) async {
    final queryParams = <String, dynamic>{};
    if (directory != null && directory.trim().isNotEmpty) {
      queryParams['directory'] = directory;
    }
    final response = await dio.get(
      '/experimental/worktree',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(WorktreeModel.fromJson)
          .toList(growable: false);
    }
    if (data is Map<String, dynamic>) {
      final list = data['worktrees'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .map(WorktreeModel.fromJson)
            .toList(growable: false);
      }
    }
    return const <WorktreeModel>[];
  }

  @override
  Future<WorktreeModel> createWorktree(String name, {String? directory}) async {
    final queryParams = <String, dynamic>{};
    if (directory != null && directory.trim().isNotEmpty) {
      queryParams['directory'] = directory;
    }
    final response = await dio.post(
      '/experimental/worktree',
      data: <String, dynamic>{'name': name},
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    return WorktreeModel.fromJson(Map<String, dynamic>.from(response.data));
  }

  @override
  Future<void> resetWorktree(String worktreeId, {String? directory}) async {
    final queryParams = <String, dynamic>{};
    if (directory != null && directory.trim().isNotEmpty) {
      queryParams['directory'] = directory;
    }
    await dio.post(
      '/experimental/worktree/reset',
      data: <String, dynamic>{'id': worktreeId},
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
  }

  @override
  Future<void> deleteWorktree(String worktreeId, {String? directory}) async {
    final queryParams = <String, dynamic>{'id': worktreeId};
    if (directory != null && directory.trim().isNotEmpty) {
      queryParams['directory'] = directory;
    }
    await dio.delete('/experimental/worktree', queryParameters: queryParams);
  }

  @override
  Future<List<String>> listDirectories(String directory) async {
    final normalized = directory.trim();
    final response = await dio.get(
      '/file',
      queryParameters: <String, dynamic>{'directory': normalized, 'path': '.'},
    );
    final data = response.data;
    if (data is! List) {
      return const <String>[];
    }

    final results = <String>[];
    for (final item in data.whereType<Map>()) {
      final node = Map<String, dynamic>.from(item);
      final type = node['type'] as String?;
      if (type != 'directory') {
        continue;
      }
      final absolute = node['absolute'] as String?;
      if (absolute == null || absolute.trim().isEmpty) {
        continue;
      }
      results.add(absolute.trim());
    }
    return results;
  }

  @override
  Future<bool> isGitDirectory(String directory) async {
    final response = await dio.get(
      '/vcs',
      queryParameters: <String, dynamic>{'directory': directory.trim()},
    );
    final data = response.data;
    if (data is! Map) {
      return false;
    }
    final map = Map<String, dynamic>.from(data);
    final branch = map['branch'] as String?;
    return branch != null && branch.trim().isNotEmpty;
  }

  @override
  Future<List<FileNodeModel>> listFiles({
    String? directory,
    required String path,
  }) async {
    final queryParams = <String, dynamic>{'path': path.trim()};
    if (directory != null && directory.trim().isNotEmpty) {
      queryParams['directory'] = directory.trim();
    }
    final response = await dio.get('/file', queryParameters: queryParams);
    final data = response.data;
    if (data is! List) {
      return const <FileNodeModel>[];
    }
    final normalizedPath = path.trim();
    final normalizedDirectory = directory?.trim();
    final parentPath = normalizedPath.isEmpty
        ? '.'
        : (normalizedPath == '.' &&
              normalizedDirectory != null &&
              normalizedDirectory.isNotEmpty)
        ? normalizedDirectory
        : normalizedPath;
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map((item) => FileNodeModel.fromJson(item, parentPath: parentPath))
        .toList(growable: false);
  }

  @override
  Future<List<FileNodeModel>> findFiles({
    String? directory,
    required String query,
    int limit = 50,
  }) async {
    final queryParams = <String, dynamic>{
      'query': query.trim(),
      'limit': '$limit',
    };
    if (directory != null && directory.trim().isNotEmpty) {
      queryParams['directory'] = directory.trim();
    }
    final response = await dio.get('/find/file', queryParameters: queryParams);
    final data = response.data;
    if (data is! List) {
      return const <FileNodeModel>[];
    }
    return data
        .map((item) {
          if (item is String) {
            return FileNodeModel.fromJson(<String, dynamic>{
              'path': item,
              'name': item.split('/').last,
              'type': 'file',
            }, parentPath: '/');
          }
          if (item is Map) {
            return FileNodeModel.fromJson(
              Map<String, dynamic>.from(item),
              parentPath: '/',
            );
          }
          return FileNodeModel.fromJson(const <String, dynamic>{
            'path': '',
            'name': 'file',
            'type': 'unknown',
          }, parentPath: '/');
        })
        .where((item) => item.path.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<FileContentModel> readFileContent({
    String? directory,
    required String path,
  }) async {
    final queryParams = <String, dynamic>{'path': path.trim()};
    if (directory != null && directory.trim().isNotEmpty) {
      queryParams['directory'] = directory.trim();
    }
    final response = await dio.get(
      '/file/content',
      queryParameters: queryParams,
    );
    return FileContentModel.fromResponse(response.data, path: path.trim());
  }
}
