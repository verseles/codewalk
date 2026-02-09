import '../models/project_model.dart';

/// Technical comment translated to English.
abstract class ProjectRemoteDataSource {
  /// Technical comment translated to English.
  Future<ProjectsResponseModel> getProjects();

  /// Technical comment translated to English.
  Future<ProjectModel> getCurrentProject({String? directory});

  /// Technical comment translated to English.
  Future<ProjectModel> getProject(String projectId);
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
    final response = await dio.get('/project/current');
    return ProjectModel.fromJson(response.data);
  }
}
