import 'dart:async';

import 'package:codewalk/core/tailscale/tailscale_http_adapter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _HangingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Completer<http.StreamedResponse>().future;
}

class _OkClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        const Stream<List<int>>.empty(),
        200,
        request: request,
      );
}

RequestOptions _options({Duration? connectTimeout}) => RequestOptions(
  path: 'http://100.123.123.1:4096/global/health',
  method: 'GET',
  connectTimeout: connectTimeout,
);

void main() {
  group('TailscaleHttpAdapter timeouts', () {
    test('stalled native call fails with connectionTimeout', () async {
      final adapter = TailscaleHttpAdapter(_HangingClient());
      final options = _options(
        connectTimeout: const Duration(milliseconds: 50),
      );
      expect(
        adapter.fetch(options, null, null),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.connectionTimeout,
          ),
        ),
      );
    });

    test('fast response still succeeds', () async {
      final adapter = TailscaleHttpAdapter(_OkClient());
      final body = await adapter.fetch(
        _options(connectTimeout: const Duration(seconds: 5)),
        null,
        null,
      );
      expect(body.statusCode, 200);
    });
  });
}
