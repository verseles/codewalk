import '../models/provider_model.dart';
import '../models/app_info_model.dart';

/// Technical comment translated to English.
abstract class AppRemoteDataSource {
  /// Technical comment translated to English.
  Future<AppInfoModel> getAppInfo({String? directory});

  /// Technical comment translated to English.
  Future<bool> initializeApp({String? directory});

  /// Technical comment translated to English.
  Future<ProvidersResponseModel> getProviders({String? directory});

  /// Technical comment translated to English.
  Future<Map<String, dynamic>> getConfig({String? directory});
}

/// Technical comment translated to English.
class AppRemoteDataSourceImpl implements AppRemoteDataSource {
  final dynamic dio;

  AppRemoteDataSourceImpl({required this.dio});

  @override
  Future<AppInfoModel> getAppInfo({String? directory}) async {
    // Use GET /app which returns the full App object directly.
    final queryParams = directory != null
        ? {'directory': directory}
        : <String, dynamic>{};

    final response = await dio.get('/app', queryParameters: queryParams);
    return AppInfoModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<bool> initializeApp({String? directory}) async {
    try {
      final queryParams = directory != null
          ? {'directory': directory}
          : <String, dynamic>{};
      final response = await dio.post(
        '/app/init',
        queryParameters: queryParams,
      );
      return response.data['success'] ?? true;
    } catch (e) {
      print('Error while initializing app: $e');
      return false;
    }
  }

  @override
  Future<ProvidersResponseModel> getProviders({String? directory}) async {
    final queryParams = directory != null
        ? {'directory': directory}
        : <String, dynamic>{};
    final response = await dio.get('/provider', queryParameters: queryParams);
    return ProvidersResponseModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  @override
  Future<Map<String, dynamic>> getConfig({String? directory}) async {
    final queryParams = directory != null
        ? {'directory': directory}
        : <String, dynamic>{};
    final response = await dio.get('/config', queryParameters: queryParams);
    return response.data as Map<String, dynamic>;
  }
}
