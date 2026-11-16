import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk/features/sessions/project_icon_view.dart';
import 'package:codewalk/platform/sessions/project_icon_loader.dart';
import 'package:codewalk/platform/sessions/project_icon_loader_io.dart';
import 'package:codewalk/platform/sessions/project_icon_loader_stub.dart'
    as stub;
import 'package:codewalk/shared/sessions/project_icon_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

class Headers extends Fake implements HttpHeaders {
  final values = <String, String>{};
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      values[name] = '$value';
  @override
  String? value(String name) => values[name];
  @override
  ContentType? get contentType => value(HttpHeaders.contentTypeHeader) == null
      ? null
      : ContentType.parse(value(HttpHeaders.contentTypeHeader)!);
}

class Response extends Stream<List<int>> implements HttpClientResponse {
  Response(
    this.chunks, {
    this.statusCode = 200,
    this.contentLength = -1,
    String? location,
    String? mime,
  }) {
    if (location != null) headers.values[HttpHeaders.locationHeader] = location;
    if (mime != null) headers.values[HttpHeaders.contentTypeHeader] = mime;
  }
  final List<List<int>> chunks;
  @override
  final int statusCode;
  @override
  final int contentLength;
  @override
  final Headers headers = Headers();
  @override
  bool get isRedirect => statusCode == 302;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.fromIterable(chunks).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Request extends Fake implements HttpClientRequest {
  Request(this.response);
  final Response response;
  @override
  final Headers headers = Headers();
  @override
  bool followRedirects = true;
  @override
  Future<HttpClientResponse> close() async => response;
}

class Client extends Fake implements HttpClient {
  Client(this.responses);
  final List<Response> responses;
  final uris = <Uri>[];
  final requests = <Request>[];
  bool closed = false;
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    uris.add(url);
    final request = Request(responses.removeAt(0));
    requests.add(request);
    return request;
  }

  @override
  void close({bool force = false}) => closed = force;
}

void main() {
  test(
    'network icons use anonymous requests, validated redirects, and close',
    () async {
      final client = Client([
        Response([], statusCode: 302, location: '/image.png'),
        Response([
          [1, 2, 3],
        ], mime: 'image/png'),
      ]);
      final result = await HttpOverrides.runZoned(
        () => loadNetworkProjectIcon(Uri.parse('https://example.com/start')),
        createHttpClient: (_) => client,
      );
      expect(result?.bytes, [1, 2, 3]);
      expect(client.uris.last.path, '/image.png');
      expect(client.requests.every((r) => !r.followRedirects), isTrue);
      expect(
        client.requests.every(
          (r) => r.headers.values.keys.toList().join() == 'accept',
        ),
        isTrue,
      );
      expect(client.closed, isTrue);
    },
  );

  test(
    'unsafe redirects, missing locations, status and byte limits fall back',
    () async {
      for (final response in [
        Response([], statusCode: 302, location: 'http://example.com/plain'),
        Response(
          [],
          statusCode: 302,
          location: 'https://u:p@example.com/secret',
        ),
        Response([], statusCode: 302),
        Response([], statusCode: 404),
        Response([], contentLength: ProjectIconData.maxBytes + 1),
        Response([
          List.filled(ProjectIconData.maxBytes, 1),
          [1],
        ]),
        Response([
          [1],
        ], mime: 'text/html'),
      ]) {
        final client = Client([response]);
        final result = await HttpOverrides.runZoned(
          () => loadNetworkProjectIcon(Uri.parse('https://example.com/icon')),
          createHttpClient: (_) => client,
        );
        expect(result, isNull);
        expect(client.closed, isTrue);
        expect(client.requests, hasLength(1));
      }
    },
  );

  test('redirect loops and failed requests stay finite', () async {
    for (final responses in [
      <Response>[],
      List.generate(
        4,
        (_) => Response([], statusCode: 302, location: '/again'),
      ),
    ]) {
      final client = Client(responses);
      expect(
        await HttpOverrides.runZoned(
          () => loadNetworkProjectIcon(Uri.parse('https://example.com/icon')),
          createHttpClient: (_) => client,
        ),
        isNull,
      );
      expect(client.closed, isTrue);
      expect(client.requests.length, lessThanOrEqualTo(4));
    }
    expect(await loadNetworkProjectIcon(Uri.parse('file:///tmp/icon')), isNull);
    expect(
      await stub.loadNetworkProjectIcon(Uri.parse('https://example.com/icon')),
      isNull,
    );
  });

  testWidgets('an equal URL is retried on rebuild after its cache entry leaves', (
    tester,
  ) async {
    final first = Client([Response([], statusCode: 404)]);
    final retry = Client([
      Response([
        utf8.encode(
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10" fill="red"/></svg>',
        ),
      ], mime: 'image/svg+xml'),
    ]);
    final clients = [first, retry];
    final uri = Uri.parse('https://example.com/retry-on-rebuild.svg');
    await HttpOverrides.runZoned(() async {
      Future<void> rebuild() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ProjectIconView(source: uri)),
          ),
        );
        await tester.pumpAndSettle();
      }

      await rebuild();
      expect(find.byIcon(Symbols.folder_open), findsOneWidget);
      expect(first.requests, hasLength(1));
      await rebuild();
      expect(retry.requests, isEmpty);
      // Eviction makes the next lookup miss, just like expiry, without a
      // real-time wait or exposing cache internals to the widget.
      for (var i = 0; i < 33; i++) {
        await loadProjectIcon(
          Uri.dataFromString('evict$i', mimeType: 'image/png'),
        );
      }
      await rebuild();
      expect(retry.requests, hasLength(1));
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, createHttpClient: (_) => clients.removeAt(0));
  });

  test('concurrent surfaces share the bounded image cache', () async {
    final client = Client([
      Response([
        [1],
      ], mime: 'image/png'),
    ]);
    final uri = Uri.parse('https://example.com/shared.png');
    await HttpOverrides.runZoned(() async {
      final first = loadProjectIcon(uri);
      final second = loadProjectIcon(uri);
      expect(identical(first, second), isTrue);
      expect(await first, isNotNull);
      expect(client.requests, hasLength(1));
      for (var i = 0; i < 33; i++) {
        await loadProjectIcon(
          Uri.dataFromString('icon$i', mimeType: 'image/png'),
        );
      }
    }, createHttpClient: (_) => client);
  });
}
