import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../repositories/chat_repository.dart';

class AbortChatSession {
  const AbortChatSession(this.repository);

  final ChatRepository repository;

  Future<Either<Failure, void>> call(AbortChatSessionParams params) {
    return repository.abortSession(
      params.projectId,
      params.sessionId,
      directory: params.directory,
    );
  }
}

class AbortChatSessionParams {
  const AbortChatSessionParams({
    required this.projectId,
    required this.sessionId,
    this.directory,
  });

  final String projectId;
  final String sessionId;
  final String? directory;
}
