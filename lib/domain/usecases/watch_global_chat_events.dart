import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/chat_realtime.dart';
import '../repositories/chat_repository.dart';

class WatchGlobalChatEvents {
  const WatchGlobalChatEvents(this.repository);

  final ChatRepository repository;

  Stream<Either<Failure, ChatEvent>> call() {
    return repository.subscribeGlobalEvents();
  }
}
