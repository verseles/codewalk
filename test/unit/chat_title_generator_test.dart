import 'dart:async';
import 'dart:convert';

import 'package:codewalk/presentation/services/chat_title_generator.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper to build a message envelope matching the real API format:
/// `{ "info": { "role": role, "time": { "completed": ms } }, "parts": [...] }`
Map<String, dynamic> _envelope({
  required String role,
  bool completed = false,
  List<Map<String, dynamic>> parts = const [],
}) {
  return <String, dynamic>{
    'info': <String, dynamic>{
      'role': role,
      'time': <String, dynamic>{
        'created': 1700000000000,
        if (completed) 'completed': 1700000001000,
      },
    },
    'parts': parts,
  };
}

Map<String, dynamic> _textPart(String text) {
  return <String, dynamic>{'type': 'text', 'text': text};
}

Future<void> _waitForWaiters(
  OpenCodeTitleGenerator generator,
  int count,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (generator.pendingWaiterCount == count) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Expected $count title waiters, found ${generator.pendingWaiterCount}');
}

Future<void> _waitForAdapterCalls(_MockDioAdapter adapter, int count) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (adapter.callCount == count) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Expected $count adapter calls, found ${adapter.callCount}');
}

void main() {
  group('OpenCodeTitleGenerator', () {
    late Dio dio;
    late _MockDioAdapter adapter;
    late OpenCodeTitleGenerator generator;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://localhost:4096'));
      adapter = _MockDioAdapter();
      dio.httpClientAdapter = adapter;
      generator = OpenCodeTitleGenerator(dio: dio, waitTimeout: Duration.zero);
    });

    tearDown(ChatTitleGenerator.ephemeralSessionIds.clear);

    test('returns null for empty messages', () async {
      final result = await generator.generateTitle([]);
      expect(result, isNull);
    });

    test(
      'reads one authoritative snapshot after the bounded fallback',
      () async {
        adapter.enqueue([
          // POST /session
          _MockResponse(200, <String, dynamic>{'id': 'ses_temp_1'}),
          // POST /session/ses_temp_1/message
          _MockResponse(200, <String, dynamic>{'id': 'msg_1'}),
          // GET /session/ses_temp_1/message (single final snapshot)
          _MockResponse(200, <dynamic>[
            _envelope(role: 'user', parts: [_textPart('hello')]),
            _envelope(
              role: 'assistant',
              completed: true,
              parts: [_textPart('Greeting Conversation')],
            ),
          ]),
          // DELETE /session/ses_temp_1
          _MockResponse(200, null),
        ]);

        final result = await generator.generateTitle([
          const ChatTitleGeneratorMessage(role: 'user', text: 'Hello there!'),
          const ChatTitleGeneratorMessage(
            role: 'assistant',
            text: 'Hi! How can I help?',
          ),
        ]);

        expect(result, equals('Greeting Conversation'));
        expect(
          adapter.capturedRequests.where((request) => request.method == 'GET'),
          hasLength(1),
        );
      },
    );

    test('bounded fallback waits 15 seconds before its only GET', () {
      fakeAsync((async) {
        final timedDio = Dio(BaseOptions(baseUrl: 'http://localhost:4096'));
        final timedAdapter = _MockDioAdapter();
        timedDio.httpClientAdapter = timedAdapter;
        final timedGenerator = OpenCodeTitleGenerator(dio: timedDio);
        timedAdapter.enqueue([
          _MockResponse(200, <String, dynamic>{'id': 'ses_timed'}),
          _MockResponse(200, <String, dynamic>{'id': 'msg_timed'}),
          _MockResponse(200, <dynamic>[
            _envelope(
              role: 'assistant',
              completed: true,
              parts: [_textPart('Timed Title')],
            ),
          ]),
          _MockResponse(200, null),
        ]);
        String? result;

        timedGenerator
            .generateTitle([
              const ChatTitleGeneratorMessage(role: 'user', text: 'test'),
            ])
            .then((value) => result = value);
        async.elapse(Duration.zero);
        async.flushMicrotasks();
        expect(timedAdapter.callCount, 2);

        async.elapse(const Duration(milliseconds: 14999));
        expect(timedAdapter.callCount, 2);

        async.elapse(const Duration(milliseconds: 1));
        async.elapse(Duration.zero);
        async.flushMicrotasks();
        expect(result, 'Timed Title');
        expect(
          timedAdapter.capturedRequests.where(
            (request) => request.method == 'GET',
          ),
          hasLength(1),
        );
      });
    });

    test('session idle triggers one snapshot before the fallback', () async {
      final sseGenerator = OpenCodeTitleGenerator(
        dio: dio,
        waitTimeout: const Duration(seconds: 15),
      );
      adapter.enqueue([
        _MockResponse(200, <String, dynamic>{'id': 'ses_sse'}),
        _MockResponse(200, <String, dynamic>{'id': 'msg_sse'}),
        _MockResponse(200, <dynamic>[
          _envelope(
            role: 'assistant',
            completed: true,
            parts: [_textPart('SSE Title')],
          ),
        ]),
        _MockResponse(200, null),
      ]);

      final future = sseGenerator.generateTitle(<ChatTitleGeneratorMessage>[
        const ChatTitleGeneratorMessage(role: 'user', text: 'test'),
      ], directory: '/workspace/a');
      await _waitForWaiters(sseGenerator, 1);
      sseGenerator.notifySessionIdle(
        sessionId: 'ses_sse',
        directory: '/workspace/b',
      );
      await Future<void>.delayed(Duration.zero);
      expect(sseGenerator.pendingWaiterCount, 1);
      expect(
        adapter.capturedRequests.where((request) => request.method == 'GET'),
        isEmpty,
      );
      sseGenerator.notifySessionIdle(
        sessionId: 'ses_sse',
        directory: '/workspace/a/',
      );

      expect(await future, equals('SSE Title'));
      expect(sseGenerator.pendingWaiterCount, 0);
      expect(
        adapter.capturedRequests.where((request) => request.method == 'GET'),
        hasLength(1),
      );
      expect(
        adapter.capturedRequests.map(
          (request) => request.queryParameters['directory'],
        ),
        everyElement('/workspace/a'),
      );
    });

    test(
      'cancellation skips the final snapshot and clears the waiter',
      () async {
        final blockingGenerator = OpenCodeTitleGenerator(
          dio: dio,
          waitTimeout: const Duration(seconds: 15),
        );
        adapter.enqueue([
          _MockResponse(200, <String, dynamic>{'id': 'ses_cancel'}),
          _MockResponse(200, <String, dynamic>{'id': 'msg_cancel'}),
          _MockResponse(200, null),
        ]);

        final future = blockingGenerator.generateTitle([
          const ChatTitleGeneratorMessage(role: 'user', text: 'test'),
        ]);
        await _waitForWaiters(blockingGenerator, 1);
        blockingGenerator.cancelPendingWaiters();

        expect(await future, isNull);
        expect(blockingGenerator.pendingWaiterCount, 0);
        expect(
          adapter.capturedRequests.where((request) => request.method == 'GET'),
          isEmpty,
        );
        expect(adapter.capturedRequests.last.method, equals('DELETE'));
      },
    );

    test(
      'cancellation during session creation prevents waiter and GET',
      () async {
        final createGate = Completer<void>();
        final blockingGenerator = OpenCodeTitleGenerator(
          dio: dio,
          waitTimeout: const Duration(seconds: 15),
        );
        adapter.enqueue([
          _MockResponse(200, <String, dynamic>{
            'id': 'ses_create_cancel',
          }, gate: createGate),
          _MockResponse(200, null),
        ]);

        final future = blockingGenerator.generateTitle([
          const ChatTitleGeneratorMessage(role: 'user', text: 'test'),
        ]);
        await _waitForAdapterCalls(adapter, 1);
        blockingGenerator.cancelPendingWaiters();
        createGate.complete();

        expect(await future, isNull);
        expect(blockingGenerator.pendingWaiterCount, 0);
        expect(
          adapter.capturedRequests.where((request) => request.method == 'GET'),
          isEmpty,
        );
        expect(adapter.capturedRequests.last.method, equals('DELETE'));
      },
    );

    test('concurrent session waiters complete independently', () async {
      final concurrentGenerator = OpenCodeTitleGenerator(
        dio: dio,
        waitTimeout: const Duration(seconds: 15),
      );
      adapter.enqueue([
        _MockResponse(200, <String, dynamic>{'id': 'ses_first'}),
        _MockResponse(200, <String, dynamic>{'id': 'msg_first'}),
        _MockResponse(200, <String, dynamic>{'id': 'ses_second'}),
        _MockResponse(200, <String, dynamic>{'id': 'msg_second'}),
        _MockResponse(200, <dynamic>[
          _envelope(
            role: 'assistant',
            completed: true,
            parts: [_textPart('Second Title')],
          ),
        ]),
        _MockResponse(200, null),
        _MockResponse(200, <dynamic>[
          _envelope(
            role: 'assistant',
            completed: true,
            parts: [_textPart('First Title')],
          ),
        ]),
        _MockResponse(200, null),
      ]);

      final first = concurrentGenerator.generateTitle(
        const <ChatTitleGeneratorMessage>[
          ChatTitleGeneratorMessage(role: 'user', text: 'first'),
        ],
        directory: '/workspace/first',
      );
      await _waitForWaiters(concurrentGenerator, 1);
      final second = concurrentGenerator.generateTitle(
        const <ChatTitleGeneratorMessage>[
          ChatTitleGeneratorMessage(role: 'user', text: 'second'),
        ],
        directory: '/workspace/second',
      );
      await _waitForWaiters(concurrentGenerator, 2);

      concurrentGenerator.notifySessionIdle(
        sessionId: 'ses_second',
        directory: '/workspace/second',
      );
      expect(await second, equals('Second Title'));
      expect(concurrentGenerator.pendingWaiterCount, 1);

      concurrentGenerator.notifySessionIdle(
        sessionId: 'ses_first',
        directory: '/workspace/first',
      );
      expect(await first, equals('First Title'));
      expect(concurrentGenerator.pendingWaiterCount, 0);
      expect(
        adapter.capturedRequests.where((request) => request.method == 'GET'),
        hasLength(2),
      );
    });

    test('normalizes quoted title', () async {
      adapter.enqueue([
        _MockResponse(200, <String, dynamic>{'id': 'ses_2'}),
        _MockResponse(200, <String, dynamic>{'id': 'msg_2'}),
        _MockResponse(200, <dynamic>[
          _envelope(
            role: 'assistant',
            completed: true,
            parts: [_textPart('"Quoted Title Here"')],
          ),
        ]),
        _MockResponse(200, null),
      ]);

      final result = await generator.generateTitle([
        const ChatTitleGeneratorMessage(role: 'user', text: 'test'),
      ]);
      expect(result, equals('Quoted Title Here'));
    });

    test('truncates title to 80 characters', () async {
      final longTitle = 'A' * 100;
      adapter.enqueue([
        _MockResponse(200, <String, dynamic>{'id': 'ses_3'}),
        _MockResponse(200, <String, dynamic>{'id': 'msg_3'}),
        _MockResponse(200, <dynamic>[
          _envelope(
            role: 'assistant',
            completed: true,
            parts: [_textPart(longTitle)],
          ),
        ]),
        _MockResponse(200, null),
      ]);

      final result = await generator.generateTitle([
        const ChatTitleGeneratorMessage(role: 'user', text: 'test'),
      ]);
      expect(result, hasLength(80));
    });

    test('returns null when session creation fails', () async {
      adapter.enqueue([
        _MockResponse(500, 'Internal server error', isError: true),
      ]);

      final result = await generator.generateTitle([
        const ChatTitleGeneratorMessage(role: 'user', text: 'test'),
      ]);
      expect(result, isNull);
    });

    test('returns null when session id is missing', () async {
      adapter.enqueue([_MockResponse(200, <String, dynamic>{})]);

      final result = await generator.generateTitle([
        const ChatTitleGeneratorMessage(role: 'user', text: 'test'),
      ]);
      expect(result, isNull);
    });

    test('cleans up session even on error', () async {
      adapter.enqueue([
        _MockResponse(200, <String, dynamic>{'id': 'ses_cleanup'}),
        _MockResponse(500, 'error', isError: true),
        // DELETE should still be called
        _MockResponse(200, null),
      ]);

      final result = await generator.generateTitle([
        const ChatTitleGeneratorMessage(role: 'user', text: 'test'),
      ]);
      expect(result, isNull);
      // Verify delete was attempted (adapter consumed 3 responses)
      expect(adapter.callCount, equals(3));
      expect(generator.pendingWaiterCount, 0);
      expect(
        adapter.capturedRequests.where((request) => request.method == 'GET'),
        isEmpty,
      );
    });

    test('collapses whitespace in title', () async {
      adapter.enqueue([
        _MockResponse(200, <String, dynamic>{'id': 'ses_ws'}),
        _MockResponse(200, <String, dynamic>{'id': 'msg_ws'}),
        _MockResponse(200, <dynamic>[
          _envelope(
            role: 'assistant',
            completed: true,
            parts: [_textPart('  Hello   World  \n Test  ')],
          ),
        ]),
        _MockResponse(200, null),
      ]);

      final result = await generator.generateTitle([
        const ChatTitleGeneratorMessage(role: 'user', text: 'test'),
      ]);
      expect(result, equals('Hello World Test'));
    });

    test('returns null when the single final snapshot is incomplete', () async {
      adapter.enqueue([
        _MockResponse(200, <String, dynamic>{'id': 'ses_inc'}),
        _MockResponse(200, <String, dynamic>{'id': 'msg_inc'}),
        // The final authoritative snapshot is not complete.
        _MockResponse(200, <dynamic>[
          _envelope(role: 'assistant', parts: [_textPart('partial...')]),
        ]),
        _MockResponse(200, null),
      ]);

      final result = await generator.generateTitle([
        const ChatTitleGeneratorMessage(role: 'user', text: 'test'),
      ]);
      expect(result, isNull);
      expect(
        adapter.capturedRequests.where((request) => request.method == 'GET'),
        hasLength(1),
      );
    });

    test('message POST sends agent and noReply but no model field', () async {
      adapter.enqueue([
        _MockResponse(200, <String, dynamic>{'id': 'ses_payload'}),
        _MockResponse(200, <String, dynamic>{'id': 'msg_payload'}),
        _MockResponse(200, <dynamic>[
          _envelope(
            role: 'assistant',
            completed: true,
            parts: [_textPart('Title')],
          ),
        ]),
        _MockResponse(200, null),
      ]);

      await generator.generateTitle([
        const ChatTitleGeneratorMessage(role: 'user', text: 'test'),
      ]);

      // Call #1 = POST /session, Call #2 = POST /session/{id}/message
      final messageRequest = adapter.capturedRequests[1];
      expect(messageRequest.path, contains('/session/ses_payload/message'));
      expect(messageRequest.method, equals('POST'));

      final body = messageRequest.data as Map<String, dynamic>;
      expect(body['agent'], equals('title'));
      expect(body['noReply'], isFalse);
      expect(body.containsKey('model'), isFalse);
      expect(body['parts'], isList);
    });

    test('session creation uses ephemeral title', () async {
      adapter.enqueue([
        _MockResponse(200, <String, dynamic>{'id': 'ses_title_check'}),
        _MockResponse(200, <String, dynamic>{'id': 'msg_tc'}),
        _MockResponse(200, <dynamic>[
          _envelope(
            role: 'assistant',
            completed: true,
            parts: [_textPart('Title')],
          ),
        ]),
        _MockResponse(200, null),
      ]);

      await generator.generateTitle([
        const ChatTitleGeneratorMessage(role: 'user', text: 'test'),
      ]);

      // Call #0 = POST /session
      final sessionRequest = adapter.capturedRequests[0];
      final body = sessionRequest.data as Map<String, dynamic>;
      expect(body['title'], equals(ChatTitleGenerator.ephemeralSessionTitle));
    });

    test(
      'ephemeralSessionIds retains ID after completion for trailing events',
      () {
        fakeAsync((async) {
          adapter.enqueue([
            _MockResponse(200, <String, dynamic>{'id': 'ses_delay'}),
            _MockResponse(200, <String, dynamic>{'id': 'msg_delay'}),
            _MockResponse(200, <dynamic>[
              _envelope(
                role: 'assistant',
                completed: true,
                parts: [_textPart('Title')],
              ),
            ]),
            _MockResponse(200, null),
          ]);

          late final Future<String?> future;
          future = generator.generateTitle([
            const ChatTitleGeneratorMessage(role: 'user', text: 'test'),
          ]);

          async.flushMicrotasks();

          future.then((_) {
            // Immediately after completion, ID should still be in the set
            expect(
              ChatTitleGenerator.ephemeralSessionIds.contains('ses_delay'),
              isTrue,
              reason: 'ID should remain in set to filter trailing SSE events',
            );
          });

          async.elapse(const Duration(seconds: 1));

          // After 5 seconds total, the delayed removal should fire
          async.elapse(const Duration(seconds: 5));
          expect(
            ChatTitleGenerator.ephemeralSessionIds.contains('ses_delay'),
            isFalse,
            reason: 'ID should be removed after the 5s grace period',
          );
        });
      },
    );

    test('ephemeralSessionTitle constant has expected value', () {
      expect(ChatTitleGenerator.ephemeralSessionTitle, equals('_title_gen'));
    });
  });
}

class _MockResponse {
  _MockResponse(this.statusCode, this.data, {this.isError = false, this.gate});
  final int statusCode;
  final dynamic data;
  final bool isError;
  final Completer<void>? gate;
}

class _MockDioAdapter implements HttpClientAdapter {
  final List<_MockResponse> _responses = <_MockResponse>[];
  final List<RequestOptions> capturedRequests = <RequestOptions>[];
  int callCount = 0;

  void enqueue(List<_MockResponse> items) {
    _responses.addAll(items);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedRequests.add(options);

    if (callCount >= _responses.length) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'No more mock responses (call #$callCount)',
      );
    }

    final mock = _responses[callCount];
    callCount += 1;
    await mock.gate?.future;

    if (mock.isError) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: mock.statusCode,
          data: mock.data,
        ),
      );
    }

    final encoded = _encode(mock.data);
    return ResponseBody.fromString(
      encoded,
      mock.statusCode,
      headers: <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );
  }

  String _encode(dynamic data) {
    if (data == null) return '';
    if (data is String) return data;
    return jsonEncode(data);
  }

  @override
  void close({bool force = false}) {}
}
