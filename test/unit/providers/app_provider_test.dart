import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/domain/usecases/check_connection.dart';
import 'package:codewalk/domain/usecases/get_app_info.dart';
import 'package:codewalk/domain/usecases/update_server_config.dart';
import 'package:codewalk/presentation/providers/app_provider.dart';

import '../../support/fakes.dart';

void main() {
  group('AppProvider', () {
    late FakeAppRepository repository;
    late AppProvider provider;

    setUp(() {
      repository = FakeAppRepository();
      provider = AppProvider(
        getAppInfo: GetAppInfo(repository),
        checkConnection: CheckConnection(repository),
        updateServerConfig: UpdateServerConfig(repository),
      );
    });

    test('getAppInfo sets loaded state on success', () async {
      await provider.getAppInfo();

      expect(provider.status, AppStatus.loaded);
      expect(provider.isConnected, isTrue);
      expect(provider.errorMessage, isEmpty);
      expect(provider.appInfo?.hostname, 'localhost');
    });

    test('getAppInfo sets error state on failure', () async {
      repository.appInfoResult = const Left(
        NetworkFailure('server unavailable'),
      );

      await provider.getAppInfo();

      expect(provider.status, AppStatus.error);
      expect(provider.isConnected, isFalse);
      expect(provider.errorMessage, 'server unavailable');
    });

    test(
      'updateServerConfig persists host and port in provider state',
      () async {
        final updated = await provider.updateServerConfig('10.0.0.10', 5050);

        expect(updated, isTrue);
        expect(repository.updatedHost, '10.0.0.10');
        expect(repository.updatedPort, 5050);
        expect(provider.serverHost, '10.0.0.10');
        expect(provider.serverPort, 5050);
        expect(provider.serverUrl, 'http://10.0.0.10:5050');
      },
    );
  });
}
