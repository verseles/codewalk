import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../repositories/chat_repository.dart';

class ReplyPermission {
  const ReplyPermission(this.repository);

  final ChatRepository repository;

  Future<Either<Failure, void>> call(ReplyPermissionParams params) async {
    return repository.replyPermission(
      requestId: params.requestId,
      reply: params.reply,
      message: params.message,
      directory: params.directory,
    );
  }
}

class ReplyPermissionParams {
  const ReplyPermissionParams({
    required this.requestId,
    required this.reply,
    this.message,
    this.directory,
  });

  final String requestId;
  final String reply;
  final String? message;
  final String? directory;
}
