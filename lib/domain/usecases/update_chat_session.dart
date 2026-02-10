import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/chat_session.dart';
import '../repositories/chat_repository.dart';

class UpdateChatSession {
  const UpdateChatSession(this.repository);

  final ChatRepository repository;

  Future<Either<Failure, ChatSession>> call(
    UpdateChatSessionParams params,
  ) async {
    return repository.updateSession(
      params.projectId,
      params.sessionId,
      params.input,
      directory: params.directory,
    );
  }
}

class UpdateChatSessionParams {
  const UpdateChatSessionParams({
    required this.projectId,
    required this.sessionId,
    required this.input,
    this.directory,
  });

  final String projectId;
  final String sessionId;
  final SessionUpdateInput input;
  final String? directory;
}
