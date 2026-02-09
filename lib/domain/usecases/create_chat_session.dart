import 'package:dartz/dartz.dart';
import '../entities/chat_session.dart';
import '../repositories/chat_repository.dart';
import '../../core/errors/failures.dart';

/// Technical comment translated to English.
class CreateChatSession {
  const CreateChatSession(this.repository);

  final ChatRepository repository;

  /// Technical comment translated to English.
  Future<Either<Failure, ChatSession>> call(
    CreateChatSessionParams params,
  ) async {
    return repository.createSession(
      params.projectId,
      params.input,
      directory: params.directory,
    );
  }
}

/// Technical comment translated to English.
class CreateChatSessionParams {
  const CreateChatSessionParams({
    required this.projectId,
    required this.input,
    this.directory,
  });

  final String projectId;
  final SessionCreateInput input;
  final String? directory;
}
