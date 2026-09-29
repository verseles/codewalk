import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/presentation/services/release_history_service.dart';
import 'package:dio/dio.dart';

import 'fakes.dart';

const releaseHistoryFixture = '''# Changelog

## v1.3.0 - 2026-09-29

> 📣 Future announcement

- Future fix

## v1.2.0 - 2026-09-28

> 📣 Current announcement

- Current fix

## v1.1.1 - 2026-09-27

- Maintenance only

## v1.1.0 - 2026-09-26

> 📣 Novidade em português

- Earlier fix

## v1.0.0 - 2026-09-25

> 📣 Already installed

- Baseline fix
''';

class FakeReleaseHistoryService extends ReleaseHistoryService {
  FakeReleaseHistoryService({ReleaseHistorySnapshot? snapshot})
    : snapshot =
          snapshot ??
          ReleaseHistorySnapshot(
            entries: parseReleaseHistory(releaseHistoryFixture),
          ),
      super(localDataSource: InMemoryAppLocalDataSource());

  ReleaseHistorySnapshot snapshot;
  int calls = 0;
  Future<ReleaseHistorySnapshot>? pending;

  @override
  Future<ReleaseHistorySnapshot> load({bool forceRefresh = false}) async {
    calls++;
    if (pending != null) return pending!;
    return snapshot;
  }
}

class ReleaseHistoryNoopDioClient extends DioClient {
  ReleaseHistoryNoopDioClient() : super(baseUrl: 'http://localhost');

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async => Response<T>(
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
    data: <String, dynamic>{} as T,
  );
}
