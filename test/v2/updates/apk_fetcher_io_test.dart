import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk/platform/releases/apk_fetcher_io.dart';
import 'package:codewalk/shared/releases/apk_update.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

class Headers implements HttpHeaders {
  final values = <String, String>{};
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      values[name.toLowerCase()] = '$value';
  @override
  String? value(String name) => values[name.toLowerCase()];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Stream<List<int>> interrupted(List<int> bytes) async* {
  yield bytes.take(2).toList();
  throw const SocketException('interrupted');
}

class Response extends Stream<List<int>> implements HttpClientResponse {
  Response(
    this.statusCode,
    List<int> bytes, {
    String? range,
    bool interrupt = false,
  }) : _body = interrupt ? interrupted(bytes) : Stream.value(bytes),
       contentLength = bytes.length {
    if (range != null) headers.set(HttpHeaders.contentRangeHeader, range);
    headers.set(HttpHeaders.etagHeader, '"asset"');
  }
  final Stream<List<int>> _body;
  @override
  final int statusCode;
  @override
  final int contentLength;
  @override
  final Headers headers = Headers();
  @override
  bool get isRedirect => false;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _body.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Request implements HttpClientRequest {
  Request(this.response);
  final Response response;
  @override
  final Headers headers = Headers();
  @override
  bool followRedirects = false;
  @override
  Future<HttpClientResponse> close() async => response;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Client implements HttpClient {
  Client(this.responses, {this.error});
  final IOException? error;
  final List<Response> responses;
  final requests = <Request>[];
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    if (error != null) throw error!;
    final request = Request(responses.removeAt(0));
    requests.add(request);
    return request;
  }

  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final uri = Uri.parse(
    'https://github.com/verseles/codewalk/releases/download/v2.0.0-beta.2/codewalk-android-arm64.apk',
  );
  final bytes = [1, 2, 3, 4];
  final digest = sha256.convert(bytes).toString();
  late Directory directory;
  late String path;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cw-apk-resume-');
    path = '${directory.path}/asset.part';
    await File(path).writeAsBytes([1, 2]);
    await File('$path.json').writeAsString(
      jsonEncode({
        'uri': '$uri',
        'bytes': 4,
        'sha256': digest,
        'etag': '"asset"',
      }),
    );
  });
  tearDown(() async => directory.delete(recursive: true));

  for (final failure in [
    const HandshakeException('tls'),
    const HttpException('protocol'),
  ]) {
    test('transport $failure remains a typed network error', () async {
      final fetcher = HttpClientApkFetcher(client: Client([], error: failure));
      addTearDown(fetcher.close);
      await expectLater(
        fetcher.fetchText(uri),
        throwsA(
          isA<ApkDownloadException>().having(
            (e) => e.failure,
            'failure',
            ApkUpdateFailure.network,
          ),
        ),
      );
    });
  }
  for (final sidecar in [false, true]) {
    test(
      'refuses a linked ${sidecar ? 'sidecar' : 'partial'} without touching its target',
      () async {
        final victim = File('${directory.path}/victim');
        await victim.writeAsString('preserve');
        final linked = sidecar ? '$path.json' : path;
        await File(linked).delete();
        await Link(linked).create(victim.path);
        final client = Client([]);
        final fetcher = HttpClientApkFetcher(client: client);
        addTearDown(fetcher.close);
        await expectLater(
          fetcher.download(
            uri,
            path,
            onProgress: (_, _) {},
            isCancelled: () => false,
          ),
          throwsA(
            isA<ApkDownloadException>().having(
              (e) => e.failure,
              'failure',
              ApkUpdateFailure.storage,
            ),
          ),
        );
        expect(await victim.readAsString(), 'preserve');
        expect(client.requests, isEmpty);
      },
    );
  }
  test('directory creation failure is storage, not network', () async {
    final blocked = File('${directory.path}/blocked');
    await blocked.writeAsString('file');
    final fetcher = HttpClientApkFetcher(client: Client([]));
    addTearDown(fetcher.close);
    await expectLater(
      fetcher.download(
        uri,
        '${blocked.path}/asset.part',
        onProgress: (_, _) {},
        isCancelled: () => false,
      ),
      throwsA(
        isA<ApkDownloadException>().having(
          (e) => e.failure,
          'failure',
          ApkUpdateFailure.storage,
        ),
      ),
    );
  });
  test('sidecar write failure is storage, not network', () async {
    await File('$path.json').delete();
    await Directory('$path.json').create();
    final fetcher = HttpClientApkFetcher(
      client: Client([Response(200, bytes)]),
    );
    addTearDown(fetcher.close);
    await expectLater(
      fetcher.download(
        uri,
        path,
        onProgress: (_, _) {},
        isCancelled: () => false,
      ),
      throwsA(
        isA<ApkDownloadException>().having(
          (e) => e.failure,
          'failure',
          ApkUpdateFailure.storage,
        ),
      ),
    );
  });
  for (final mode in ['partial', 'full', 'invalid-range']) {
    test('resume handles $mode without mixing representations', () async {
      final client = Client(
        mode == 'partial'
            ? [
                Response(206, [3, 4], range: 'bytes 2-3/4'),
              ]
            : mode == 'full'
            ? [Response(200, bytes)]
            : [
                Response(206, [3, 4], range: 'bytes 1-2/4'),
                Response(200, bytes),
              ],
      );
      final fetcher = HttpClientApkFetcher(client: client);
      final result = await fetcher.download(
        uri,
        path,
        expectedBytes: 4,
        expectedSha256: digest,
        onProgress: (_, _) {},
        isCancelled: () => false,
      );
      expect(
        client.requests.first.headers.value(HttpHeaders.rangeHeader),
        'bytes=2-',
      );
      expect(
        client.requests.first.headers.value(HttpHeaders.ifRangeHeader),
        '"asset"',
      );
      expect(result.bytes, 4);
      expect(result.sha256, digest);
      expect(await File(path).readAsBytes(), bytes);
      fetcher.close();
    });
  }
  test(
    'a network interruption retains the partial for the next attempt',
    () async {
      final client = Client([
        Response(200, bytes, interrupt: true),
        Response(206, [3, 4], range: 'bytes 2-3/4'),
      ]);
      final fetcher = HttpClientApkFetcher(client: client);
      Future<ApkDownloadResult> transfer() => fetcher.download(
        uri,
        path,
        expectedBytes: 4,
        expectedSha256: digest,
        onProgress: (_, _) {},
        isCancelled: () => false,
      );
      await expectLater(transfer(), throwsA(isA<Exception>()));
      expect(await File(path).readAsBytes(), [1, 2]);
      final result = await transfer();
      expect(result.sha256, digest);
      expect(
        client.requests.last.headers.value(HttpHeaders.rangeHeader),
        'bytes=2-',
      );
      fetcher.close();
    },
  );
}
