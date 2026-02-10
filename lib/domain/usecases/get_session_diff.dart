import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/chat_session.dart';
import '../repositories/chat_repository.dart';

class GetSessionDiff {
  const GetSessionDiff(this.repository);

  final ChatRepository repository;

  Future<Either<Failure, List<SessionDiff>>> call(
    GetSessionDiffParams params,
  ) async {
    return repository.getSessionDiff(
      params.projectId,
      params.sessionId,
      messageId: params.messageId,
      directory: params.directory,
    );
  }
}

class GetSessionDiffParams {
  const GetSessionDiffParams({
    required this.projectId,
    required this.sessionId,
    this.messageId,
    this.directory,
  });

  final String projectId;
  final String sessionId;
  final String? messageId;
  final String? directory;
}
