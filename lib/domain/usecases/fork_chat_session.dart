import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/chat_session.dart';
import '../repositories/chat_repository.dart';

class ForkChatSession {
  const ForkChatSession(this.repository);

  final ChatRepository repository;

  Future<Either<Failure, ChatSession>> call(
    ForkChatSessionParams params,
  ) async {
    return repository.forkSession(
      params.projectId,
      params.sessionId,
      messageId: params.messageId,
      directory: params.directory,
    );
  }
}

class ForkChatSessionParams {
  const ForkChatSessionParams({
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
