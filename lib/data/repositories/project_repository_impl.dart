import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/worktree.dart';
import '../../domain/repositories/project_repository.dart';
import '../datasources/project_remote_datasource.dart';

/// Technical comment translated to English.
class ProjectRepositoryImpl implements ProjectRepository {
  final ProjectRemoteDataSource remoteDataSource;

  ProjectRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<Project>>> getProjects() async {
    try {
      final projectsModel = await remoteDataSource.getProjects();
      return Right(projectsModel.toDomain());
    } on DioException catch (e) {
      return Left(_handleDioException(e));
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Project>> getCurrentProject({
    String? directory,
  }) async {
    try {
      final projectModel = await remoteDataSource.getCurrentProject(
        directory: directory,
      );
      return Right(projectModel.toDomain());
    } on DioException catch (e) {
      return Left(_handleDioException(e));
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Project>> getProject(String projectId) async {
    try {
      final projectModel = await remoteDataSource.getProject(projectId);
      return Right(projectModel.toDomain());
    } on DioException catch (e) {
      return Left(_handleDioException(e));
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Worktree>>> getWorktrees({
    String? directory,
  }) async {
    try {
      final models = await remoteDataSource.getWorktrees(directory: directory);
      return Right(
        models.map((item) => item.toDomain()).toList(growable: false),
      );
    } on DioException catch (e) {
      return Left(_handleDioException(e));
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Worktree>> createWorktree(
    String name, {
    String? directory,
  }) async {
    try {
      final model = await remoteDataSource.createWorktree(
        name,
        directory: directory,
      );
      return Right(model.toDomain());
    } on DioException catch (e) {
      return Left(_handleDioException(e));
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> resetWorktree(
    String worktreeId, {
    String? directory,
  }) async {
    try {
      await remoteDataSource.resetWorktree(worktreeId, directory: directory);
      return const Right(null);
    } on DioException catch (e) {
      return Left(_handleDioException(e));
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteWorktree(
    String worktreeId, {
    String? directory,
  }) async {
    try {
      await remoteDataSource.deleteWorktree(worktreeId, directory: directory);
      return const Right(null);
    } on DioException catch (e) {
      return Left(_handleDioException(e));
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
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
}
