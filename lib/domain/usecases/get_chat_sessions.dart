import 'package:dartz/dartz.dart';
import '../entities/chat_session.dart';
import '../repositories/chat_repository.dart';
import '../../core/errors/failures.dart';

/// Technical comment translated to English.
class GetChatSessions {
  const GetChatSessions(this.repository);

  final ChatRepository repository;

  /// Technical comment translated to English.
  Future<Either<Failure, List<ChatSession>>> call([
    GetChatSessionsParams? params,
  ]) async {
    return repository.getSessions(
      directory: params?.directory,
      search: params?.search,
      rootsOnly: params?.rootsOnly,
      startEpochMs: params?.startEpochMs,
      limit: params?.limit,
    );
  }
}

/// Technical comment translated to English.
class GetChatSessionsParams {
  const GetChatSessionsParams({
    this.directory,
    this.search,
    this.rootsOnly,
    this.startEpochMs,
    this.limit,
  });

  final String? directory;
  final String? search;
  final bool? rootsOnly;
  final int? startEpochMs;
  final int? limit;
}
