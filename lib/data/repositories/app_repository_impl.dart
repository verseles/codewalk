import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/app_info.dart';
import '../../domain/entities/provider.dart';
import '../../domain/repositories/app_repository.dart';
import '../datasources/app_remote_datasource.dart';
import '../datasources/app_local_datasource.dart';
import '../../core/network/dio_client.dart';

/// Technical comment translated to English.
class AppRepositoryImpl implements AppRepository {
  final AppRemoteDataSource remoteDataSource;
  final AppLocalDataSource localDataSource;
  final DioClient dioClient;

  AppRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.dioClient,
  });

  @override
  Future<Either<Failure, AppInfo>> getAppInfo({String? directory}) async {
    try {
      final appInfoModel = await remoteDataSource.getAppInfo(
        directory: directory,
      );
      return Right(appInfoModel.toEntity());
    } on DioException catch (e) {
      return Left(_handleDioException(e));
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> initializeApp({String? directory}) async {
    try {
      final result = await remoteDataSource.initializeApp(directory: directory);
      return Right(result);
    } on DioException catch (e) {
      return Left(_handleDioException(e));
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> checkConnection({String? directory}) async {
    try {
      await remoteDataSource.getAppInfo(directory: directory);
      return const Right(true);
    } on DioException catch (e) {
      return Left(_handleDioException(e));
    } on Exception catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateServerConfig(
    String host,
    int port,
  ) async {
    try {
      // Technical comment translated to English.
      await localDataSource.saveServerHost(host);
      await localDataSource.saveServerPort(port);

      // Technical comment translated to English.
      final baseUrl = 'http://$host:$port';
      dioClient.updateBaseUrl(baseUrl);

      return const Right(null);
    } on Exception catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  /// Technical comment translated to English.
  Failure _handleDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkFailure('Connection timeout');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode != null) {
          if (statusCode >= 400 && statusCode < 500) {
            return NetworkFailure('Client error', statusCode);
          } else if (statusCode >= 500) {
            return ServerFailure('Server error', statusCode);
          }
        }
        return const ServerFailure('Response error');
      case DioExceptionType.cancel:
        return const NetworkFailure('Request cancelled');
      case DioExceptionType.connectionError:
        return const NetworkFailure('Network connection error');
      case DioExceptionType.unknown:
        return NetworkFailure('Unknown network error: ${e.message}');
      case DioExceptionType.badCertificate:
        return const NetworkFailure('Certificate error');
    }
  }

  @override
  Future<Either<Failure, ProvidersResponse>> getProviders({
    String? directory,
  }) async {
    try {
      final providersModel = await remoteDataSource.getProviders(
        directory: directory,
      );
      return Right(providersModel.toDomain());
    } on DioException catch (e) {
      return Left(_handleDioException(e));
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
