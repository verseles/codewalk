import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/app_info.dart';
import '../repositories/app_repository.dart';

/// Technical comment translated to English.
class GetAppInfo {
  final AppRepository repository;

  GetAppInfo(this.repository);

  Future<Either<Failure, AppInfo>> call({String? directory}) async {
    return await repository.getAppInfo(directory: directory);
  }
}
