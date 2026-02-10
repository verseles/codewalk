import '../models/project_model.dart';
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
}
