import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/agent.dart';
import '../entities/app_info.dart';
import '../entities/provider.dart';

/// Technical comment translated to English.
abstract class AppRepository {
  /// Technical comment translated to English.
  Future<Either<Failure, AppInfo>> getAppInfo({String? directory});

  /// Technical comment translated to English.
  Future<Either<Failure, bool>> initializeApp({String? directory});

  /// Technical comment translated to English.
  Future<Either<Failure, bool>> checkConnection({String? directory});

  /// Technical comment translated to English.
  Future<Either<Failure, void>> updateServerConfig(String host, int port);

  /// Technical comment translated to English.
  Future<Either<Failure, ProvidersResponse>> getProviders({String? directory});

  /// Technical comment translated to English.
  Future<Either<Failure, List<Agent>>> getAgents({String? directory});
}
