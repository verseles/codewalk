import 'package:dartz/dartz.dart';
import '../entities/provider.dart';
import '../repositories/app_repository.dart';
import '../../core/errors/failures.dart';

/// Technical comment translated to English.
class GetProviders {
  final AppRepository repository;

  GetProviders(this.repository);

  Future<Either<Failure, ProvidersResponse>> call({String? directory}) async {
    return await repository.getProviders(directory: directory);
  }
}
