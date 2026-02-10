import 'package:dartz/dartz.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';
import '../../core/errors/failures.dart';

/// Technical comment translated to English.
class GetChatMessages {
  const GetChatMessages(this.repository);

  final ChatRepository repository;

  /// Technical comment translated to English.
  Future<Either<Failure, List<ChatMessage>>> call(
    GetChatMessagesParams params,
  ) async {
    return repository.getMessages(
      params.projectId,
      params.sessionId,
      directory: params.directory,
    );
  }
}

/// Technical comment translated to English.
class GetChatMessagesParams {
  const GetChatMessagesParams({
    required this.projectId,
    required this.sessionId,
    this.directory,
  });

  final String projectId;
  final String sessionId;
  final String? directory;
}
