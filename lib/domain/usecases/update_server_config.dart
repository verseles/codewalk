import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../repositories/app_repository.dart';

/// Technical comment translated to English.
class UpdateServerConfigParams {
  final String host;
  final int port;

  const UpdateServerConfigParams({required this.host, required this.port});
}

/// Technical comment translated to English.
class UpdateServerConfig {
  final AppRepository repository;

  UpdateServerConfig(this.repository);

  Future<Either<Failure, void>> call(UpdateServerConfigParams params) async {
    return await repository.updateServerConfig(params.host, params.port);
  }
}
