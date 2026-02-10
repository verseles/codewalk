import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/chat_session.dart';
import '../repositories/chat_repository.dart';

class GetSessionTodo {
  const GetSessionTodo(this.repository);

  final ChatRepository repository;

  Future<Either<Failure, List<SessionTodo>>> call(
    GetSessionTodoParams params,
  ) async {
    return repository.getSessionTodo(
      params.projectId,
      params.sessionId,
      directory: params.directory,
    );
  }
}

class GetSessionTodoParams {
  const GetSessionTodoParams({
    required this.projectId,
    required this.sessionId,
    this.directory,
  });

  final String projectId;
  final String sessionId;
  final String? directory;
}
