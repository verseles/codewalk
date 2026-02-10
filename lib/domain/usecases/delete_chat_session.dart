import 'package:dartz/dartz.dart';
import '../repositories/chat_repository.dart';
import '../../core/errors/failures.dart';

/// Technical comment translated to English.
class DeleteChatSessionParams {
  const DeleteChatSessionParams({
    required this.projectId,
    required this.sessionId,
    this.directory,
  });

  final String projectId;
  final String sessionId;
  final String? directory;
}

/// Technical comment translated to English.
class DeleteChatSession {
  const DeleteChatSession(this.repository);

  final ChatRepository repository;

  /// Technical comment translated to English.
  Future<Either<Failure, void>> call(DeleteChatSessionParams params) async {
    return await repository.deleteSession(
      params.projectId,
      params.sessionId,
      directory: params.directory,
    );
  }
}
