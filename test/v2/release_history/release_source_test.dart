import 'dart:async';
import 'dart:convert';

import 'package:codewalk/platform/releases/release_source_io.dart';
import 'package:codewalk/shared/releases/release_source.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTransport implements EndpointHttpTransport {
  FakeTransport(this.respond);
  final Future<TransportResponse> Function() respond;
  TransportRequest? request;
  RequestCancellation? cancellation;
  @override
  final Uri endpoint = Uri.parse('https://raw.githubusercontent.com');
  @override
  bool isClosed = false;
  @override
  Future<TransportResponse> send(
    TransportRequest value, {
    RequestCancellation? cancellation,
  }) {
    request = value;
    this.cancellation = cancellation;
    return respond();
  }

  @override
  void close() => isClosed = true;
}

void main() {
  test(
    'uses public fixed route and never adds profile authentication',
    () async {
      var cancelled = false;
      final transport = FakeTransport(
        () async => TransportResponse(
          statusCode: 200,
          headers: const {},
          body: Stream.value(utf8.encode('Olá')),
          cancel: () => cancelled = true,
        ),
      );
      final source = NativeReleaseSource(transport: transport);
      final result = await source.start().result;
      expect(result.body, 'Olá');
      expect(transport.request!.method, 'GET');
      expect(transport.request!.path, '/verseles/codewalk/main/CHANGELOG.md');
      expect(transport.request!.headers, {
        'Accept': 'text/plain',
        'Accept-Encoding': 'identity',
      });
      expect(transport.request!.body, isNull);
      expect(cancelled, isTrue);
      source.close();
      expect(transport.isClosed, isTrue);
    },
  );

  for (final invalid in [(302, null), (200, 'gzip')]) {
    test('rejects status/encoding $invalid without consuming body', () async {
      var consumed = false;
      var cancelled = false;
      final stream = StreamController<List<int>>(
        onListen: () => consumed = true,
      );
      final source = NativeReleaseSource(
        transport: FakeTransport(
          () async => TransportResponse(
            statusCode: invalid.$1,
            headers: {
              if (invalid.$2 != null) 'content-encoding': [invalid.$2!],
            },
            body: stream.stream,
            cancel: () => cancelled = true,
          ),
        ),
      );
      expect(
        (await source.start().result).failure,
        ReleaseSourceFailure.invalidResponse,
      );
      expect(consumed, isFalse);
      expect(cancelled, isTrue);
      source.close();
      unawaited(stream.close());
    });
  }

  for (final bytes in [
    [0xc3, 0x28],
    List<int>.filled(ReleaseSource.maxBodyBytes + 1, 0x61),
  ]) {
    test(
      'invalid UTF8/oversized input is a safe failure (${bytes.length})',
      () async {
        final source = NativeReleaseSource(
          transport: FakeTransport(
            () async => TransportResponse(
              statusCode: 200,
              headers: const {},
              body: Stream.value(bytes),
              cancel: () {},
            ),
          ),
        );
        final result = await source.start().result;
        expect(result.failure, ReleaseSourceFailure.unavailable);
        expect(result.body, isNull);
        source.close();
      },
    );
  }

  test('explicit cancellation suppresses a late header response', () async {
    final headers = Completer<TransportResponse>();
    final transport = FakeTransport(() => headers.future);
    final source = NativeReleaseSource(transport: transport);
    final task = source.start();
    task.cancel();
    expect((await task.result).failure, ReleaseSourceFailure.cancelled);
    expect(transport.cancellation!.isCancelled, isTrue);
    var cancelled = false;
    headers.complete(
      TransportResponse(
        statusCode: 200,
        headers: const {},
        body: const Stream.empty(),
        cancel: () => cancelled = true,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(cancelled, isTrue);
    source.close();
  });

  testWidgets(
    'total deadline completes even when transport headers never arrive',
    (tester) async {
      final transport = FakeTransport(
        () => Completer<TransportResponse>().future,
      );
      final source = NativeReleaseSource(transport: transport);
      ReleaseSourceResult? result;
      unawaited(source.start().result.then((value) => result = value));
      await tester.pump(const Duration(seconds: 30));
      expect(result!.failure, ReleaseSourceFailure.timeout);
      expect(transport.cancellation!.isCancelled, isTrue);
      source.close();
    },
  );
}
