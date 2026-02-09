import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/chat_realtime.dart';
import '../repositories/chat_repository.dart';

class ListPendingPermissions {
  const ListPendingPermissions(this.repository);

  final ChatRepository repository;

  Future<Either<Failure, List<ChatPermissionRequest>>> call({
    String? directory,
  }) async {
    return repository.listPermissions(directory: directory);
  }
}
