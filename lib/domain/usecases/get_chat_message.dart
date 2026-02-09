import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

class GetChatMessage {
  const GetChatMessage(this.repository);

  final ChatRepository repository;

  Future<Either<Failure, ChatMessage>> call(GetChatMessageParams params) async {
    return repository.getMessage(
      params.projectId,
      params.sessionId,
      params.messageId,
      directory: params.directory,
    );
  }
}

class GetChatMessageParams {
  const GetChatMessageParams({
    required this.projectId,
    required this.sessionId,
    required this.messageId,
    this.directory,
  });

  final String projectId;
  final String sessionId;
  final String messageId;
  final String? directory;
}
