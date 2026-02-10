import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/chat_realtime.dart';
import '../repositories/chat_repository.dart';

class GetSessionStatus {
  const GetSessionStatus(this.repository);

  final ChatRepository repository;

  Future<Either<Failure, Map<String, SessionStatusInfo>>> call([
    GetSessionStatusParams? params,
  ]) async {
    return repository.getSessionStatus(directory: params?.directory);
  }
}

class GetSessionStatusParams {
  const GetSessionStatusParams({this.directory});

  final String? directory;
}
