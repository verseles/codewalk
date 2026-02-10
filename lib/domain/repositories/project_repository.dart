import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/project.dart';
import '../entities/worktree.dart';

/// Technical comment translated to English.
abstract class ProjectRepository {
  /// Technical comment translated to English.
  Future<Either<Failure, List<Project>>> getProjects();

  /// Technical comment translated to English.
  Future<Either<Failure, Project>> getCurrentProject({String? directory});

  /// Technical comment translated to English.
  Future<Either<Failure, Project>> getProject(String projectId);

  /// Technical comment translated to English.
  Future<Either<Failure, List<Worktree>>> getWorktrees({String? directory});

  /// Technical comment translated to English.
  Future<Either<Failure, Worktree>> createWorktree(
    String name, {
    String? directory,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, void>> resetWorktree(
    String worktreeId, {
    String? directory,
  });

  /// Technical comment translated to English.
  Future<Either<Failure, void>> deleteWorktree(
    String worktreeId, {
    String? directory,
  });

  /// List subdirectories for a given absolute directory path.
  Future<Either<Failure, List<String>>> listDirectories(String directory);

  /// Determine whether a directory is a Git repository context.
  Future<Either<Failure, bool>> isGitDirectory(String directory);
}
