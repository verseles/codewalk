import 'package:dartz/dartz.dart';
import '../entities/chat_message.dart';
import '../entities/chat_session.dart';
import '../repositories/chat_repository.dart';
import '../../core/errors/failures.dart';

/// Technical comment translated to English.
class SendChatMessage {
  const SendChatMessage(this.repository);

  final ChatRepository repository;

  /// Technical comment translated to English.
  Stream<Either<Failure, ChatMessage>> call(SendChatMessageParams params) {
    return repository.sendMessage(
      params.projectId,
      params.sessionId,
      params.input,
      directory: params.directory,
    );
  }
}

/// Technical comment translated to English.
class SendChatMessageParams {
  const SendChatMessageParams({
    required this.projectId,
    required this.sessionId,
    required this.input,
    this.directory,
  });

  final String projectId;
  final String sessionId;
  final ChatInput input;
  final String? directory;
}
