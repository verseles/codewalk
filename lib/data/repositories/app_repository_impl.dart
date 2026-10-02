import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/network/dio_client.dart';
import '../../domain/entities/agent.dart';
import '../../domain/entities/app_info.dart';
import '../../domain/entities/provider.dart';
import '../../domain/repositories/app_repository.dart';
import '../datasources/app_local_datasource.dart';
import '../datasources/app_remote_datasource.dart';
import 'dio_exception_handler.dart';

/// Technical comment translated to English.
class AppRepositoryImpl with DioExceptionHandler implements AppRepository {

  AppRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.dioClient,
  });
  final AppRemoteDataSource remoteDataSource;
  final AppLocalDataSource localDataSource;
  final DioClient dioClient;

  @override
  Future<Either<Failure, AppInfo>> getAppInfo({String? directory}) async {
    try {
      final appInfoModel = await remoteDataSource.getAppInfo(
        directory: directory,
      );
      return Right(appInfoModel.toEntity());
    } on DioException catch (e) {
      if (e.error is FormatException) {
        return const Left(ParseFailure('Invalid OpenCode JSON response.'));
      }
      return Left(handleDioException(e));
    } on ParseException catch (e) {
      return Left(ParseFailure(e.message));
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
      return Left(handleDioException(e));
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
      if (e.error is FormatException) {
        return const Left(ParseFailure('Invalid OpenCode JSON response.'));
      }
      return Left(handleDioException(e));
    } on ParseException catch (e) {
      return Left(ParseFailure(e.message));
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
      return Left(handleDioException(e));
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Agent>>> getAgents({String? directory}) async {
    try {
      final agentModels = await remoteDataSource.getAgents(
        directory: directory,
      );
      final agents = agentModels
          .map((model) => model.toDomain())
          .toList(growable: false);
      return Right(agents);
    } on DioException catch (e) {
      return Left(handleDioException(e));
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
