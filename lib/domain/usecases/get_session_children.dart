import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/chat_session.dart';
import '../repositories/chat_repository.dart';

class GetSessionChildren {
  const GetSessionChildren(this.repository);

  final ChatRepository repository;

  Future<Either<Failure, List<ChatSession>>> call(
    GetSessionChildrenParams params,
  ) async {
    return repository.getSessionChildren(
      params.projectId,
      params.sessionId,
      directory: params.directory,
    );
  }
}

class GetSessionChildrenParams {
  const GetSessionChildrenParams({
    required this.projectId,
    required this.sessionId,
    this.directory,
  });

  final String projectId;
  final String sessionId;
  final String? directory;
}
