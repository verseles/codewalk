import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/agent.dart';
import '../repositories/app_repository.dart';

/// Technical comment translated to English.
class GetAgents {
  final AppRepository repository;

  GetAgents(this.repository);

  Future<Either<Failure, List<Agent>>> call({String? directory}) async {
    return await repository.getAgents(directory: directory);
  }
}
