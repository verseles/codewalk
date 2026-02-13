import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../repositories/chat_repository.dart';

class SummarizeChatSession {
  const SummarizeChatSession(this.repository);

  final ChatRepository repository;

  Future<Either<Failure, void>> call(SummarizeChatSessionParams params) {
    return repository.summarizeSession(
      params.projectId,
      params.sessionId,
      providerId: params.providerId,
      modelId: params.modelId,
      directory: params.directory,
    );
  }
}

class SummarizeChatSessionParams {
  const SummarizeChatSessionParams({
    required this.projectId,
    required this.sessionId,
    required this.providerId,
    required this.modelId,
    this.directory,
  });

  final String projectId;
  final String sessionId;
  final String providerId;
  final String modelId;
  final String? directory;
}
