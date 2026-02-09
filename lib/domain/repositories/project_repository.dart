import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/project.dart';

/// Technical comment translated to English.
abstract class ProjectRepository {
  /// Technical comment translated to English.
  Future<Either<Failure, List<Project>>> getProjects();

  /// Technical comment translated to English.
  Future<Either<Failure, Project>> getCurrentProject({String? directory});

  /// Technical comment translated to English.
  Future<Either<Failure, Project>> getProject(String projectId);
}
