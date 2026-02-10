import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../repositories/app_repository.dart';

/// Technical comment translated to English.
class CheckConnection {
  final AppRepository repository;

  CheckConnection(this.repository);

  Future<Either<Failure, bool>> call({String? directory}) async {
    return await repository.checkConnection(directory: directory);
  }
}
