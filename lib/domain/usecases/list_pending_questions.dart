import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/chat_realtime.dart';
import '../repositories/chat_repository.dart';

class ListPendingQuestions {
  const ListPendingQuestions(this.repository);

  final ChatRepository repository;

  Future<Either<Failure, List<ChatQuestionRequest>>> call({
    String? directory,
  }) async {
    return repository.listQuestions(directory: directory);
  }
}
