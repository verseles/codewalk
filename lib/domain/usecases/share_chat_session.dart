import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/chat_session.dart';
import '../repositories/chat_repository.dart';

class ShareChatSession {
  const ShareChatSession(this.repository);

  final ChatRepository repository;

  Future<Either<Failure, ChatSession>> call(
    ShareChatSessionParams params,
  ) async {
    return repository.shareSession(
      params.projectId,
      params.sessionId,
      directory: params.directory,
    );
  }
}

class ShareChatSessionParams {
  const ShareChatSessionParams({
    required this.projectId,
    required this.sessionId,
    this.directory,
  });

  final String projectId;
  final String sessionId;
  final String? directory;
}
