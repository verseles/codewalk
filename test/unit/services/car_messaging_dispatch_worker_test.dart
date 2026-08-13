import 'dart:convert';
import 'dart:typed_data';

import 'package:codewalk/data/car_messaging/car_messaging_file_store.dart';
import 'package:codewalk/data/car_messaging/car_messaging_store.dart';
import 'package:codewalk/domain/entities/car_messaging.dart';
import 'package:codewalk/domain/entities/session_attention_overlay/session_attention_models.dart';
import 'package:codewalk/presentation/services/car_messaging/car_messaging_dispatch_worker.dart';
import 'package:codewalk/presentation/services/car_messaging/car_messaging_notification.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryKeyStorage implements CarMessagingKeyStorage {
  String? value;
  @override
  Future<void> delete() async => value = null;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

class _MemoryFileStore implements CarMessagingFileStore {
  String? value;
  @override
  Future<void> delete() async => value = null;
  @override
  Future<String?> read() async => value;
  @override
  Future<T> synchronized<T>(Future<T> Function() operation) => operation();
  @override
  Future<void> writeAtomically(String value) async => this.value = value;
}

class _RecordingNotifier extends CarMessagingNotifier {
  final List<CarMessagingThread> shown = <CarMessagingThread>[];
  final List<SessionAttentionIdentity> failures = <SessionAttentionIdentity>[];

  @override
  Future<void> show(CarMessagingThread thread) async => shown.add(thread);

  @override
  Future<void> showDeliveryFailure({
    required SessionAttentionIdentity identity,
  }) async => failures.add(identity);
}

Map<String, dynamic> _messageEnvelope(
  String id, {
  required int created,
  required int completed,
  String? text,
}) {
  return <String, dynamic>{
    'info': <String, dynamic>{
      'id': id,
      'sessionID': 'session-a',
      'role': 'assistant',
      'time': <String, int>{'created': created, 'completed': completed},
    },
    'parts': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'part-$id',
        'messageID': id,
        'sessionID': 'session-a',
        'type': 'text',
        'text': text ?? 'Final $id',
      },
    ],
  };
}

class _ReplyAdapter implements HttpClientAdapter {
  _ReplyAdapter({
    this.failConnect = false,
    this.rejectPost = false,
    this.tailOnlyBaseline = false,
  });

  final bool failConnect;
  final bool rejectPost;
  final bool tailOnlyBaseline;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'POST') {
      if (failConnect) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }
      if (rejectPost) {
        return ResponseBody.fromString(
          '{}',
          500,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      }
      return ResponseBody.fromString('', 204);
    }
    return ResponseBody.fromString(
      jsonEncode(<Map<String, dynamic>>[
        _messageEnvelope(
          'message-old',
          created: 800,
          completed: 900,
          text: 'Previous',
        ),
        if (!tailOnlyBaseline)
          _messageEnvelope(
            'message-new',
            created: 1000,
            completed: 1100,
            text: 'Final answer',
          ),
      ]),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'sends prompt_async once without messageID then posts new final',
    () async {
      final files = _MemoryFileStore();
      final store = CarMessagingStore(
        keyStorage: _MemoryKeyStorage(),
        fileStore: files,
        now: () => DateTime.fromMillisecondsSinceEpoch(1000),
      );
      const identity = SessionAttentionIdentity(
        serverId: 'server-a',
        directory: '/work/app',
        rootSessionId: 'session-a',
      );
      await store.upsertThread(
        const CarMessagingThread(
          identity: identity,
          title: 'Session',
          entries: <CarMessagingEntry>[
            CarMessagingEntry(
              role: CarMessagingRole.agent,
              text: 'Previous',
              timestampEpochMs: 1,
              messageId: 'message-old',
            ),
          ],
          updatedAtEpochMs: 900,
        ),
      );
      await store.enqueueReply(
        const CarMessagingReply(
          id: 'reply-a',
          identity: identity,
          text: 'Continue',
          createdAtEpochMs: 950,
          baselineAssistantMessageId: 'message-old',
        ),
      );
      final adapter = _ReplyAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
        ..httpClientAdapter = adapter;
      final notifier = _RecordingNotifier();
      final worker = CarMessagingDispatchWorker(
        dio: dio,
        serverId: 'server-a',
        store: store,
        notifier: notifier,
        now: () => DateTime.fromMillisecondsSinceEpoch(1000),
      );

      final result = await worker.processReplies(const <String, String>{});

      expect(result.pending, isFalse);
      expect(result.notifiedSessionIds, contains('session-a'));
      final post = adapter.requests.singleWhere(
        (request) => request.method == 'POST',
      );
      expect(post.path, '/session/session-a/prompt_async');
      expect(post.queryParameters['directory'], '/work/app');
      expect(post.data, isNot(containsPair('messageID', anything)));
      expect((post.data as Map)['parts'], <Map<String, dynamic>>[
        <String, dynamic>{'type': 'text', 'text': 'Continue'},
      ]);
      expect((await store.read()).replies, isEmpty);
      expect(notifier.shown.single.entries.last.text, 'Final answer');
    },
  );

  test('publishCompletion reuses equivalent normalized identity', () async {
    final store = CarMessagingStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: _MemoryFileStore(),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    const identity = SessionAttentionIdentity(
      serverId: 'server-a',
      directory: r'\work\app\',
      rootSessionId: 'session-a',
    );
    await store.upsertThread(
      const CarMessagingThread(
        identity: identity,
        title: 'Existing title',
        entries: <CarMessagingEntry>[
          CarMessagingEntry(
            role: CarMessagingRole.user,
            text: 'Keep this reply',
            timestampEpochMs: 1,
          ),
        ],
        updatedAtEpochMs: 900,
      ),
    );
    final adapter = _ReplyAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter;
    final notifier = _RecordingNotifier();
    final worker = CarMessagingDispatchWorker(
      dio: dio,
      serverId: 'server-a',
      store: store,
      notifier: notifier,
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );

    expect(
      await worker.publishCompletion(
        sessionId: 'session-a',
        directory: '/work/app/',
        title: 'Fallback title',
      ),
      CarMessagingCompletionResult.published,
    );
    final thread = (await store.read()).threads.single;
    expect(thread.title, 'Existing title');
    expect(thread.entries.map((entry) => entry.text), <String>[
      'Keep this reply',
      'Final answer',
    ]);
  });

  test('older assistant messages are never treated as the new final', () async {
    final store = CarMessagingStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: _MemoryFileStore(),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    const identity = SessionAttentionIdentity(
      serverId: 'server-a',
      directory: '/work/app',
      rootSessionId: 'session-a',
    );
    await store.enqueueReply(
      const CarMessagingReply(
        id: 'reply-a',
        identity: identity,
        text: 'Continue',
        createdAtEpochMs: 950,
        baselineAssistantMessageId: 'message-old',
      ),
    );
    final adapter = _ReplyAdapter(tailOnlyBaseline: true);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter;
    final notifier = _RecordingNotifier();
    final worker = CarMessagingDispatchWorker(
      dio: dio,
      serverId: 'server-a',
      store: store,
      notifier: notifier,
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final result = await worker.processReplies(const <String, String>{});

    expect(result.pending, isTrue);
    expect(
      (await store.read()).replies.single.state,
      CarMessagingReplyState.awaitingFinal,
    );
    expect(notifier.shown, isEmpty);
  });

  test('assistant message before the reply timestamp is ignored', () async {
    final store = CarMessagingStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: _MemoryFileStore(),
      now: () => DateTime.fromMillisecondsSinceEpoch(5000),
    );
    const identity = SessionAttentionIdentity(
      serverId: 'server-a',
      directory: '/work/app',
      rootSessionId: 'session-a',
    );
    await store.enqueueReply(
      const CarMessagingReply(
        id: 'reply-a',
        identity: identity,
        text: 'Continue',
        createdAtEpochMs: 4000,
        baselineAssistantMessageId: 'message-old',
      ),
    );
    final adapter = _ReplyAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter;
    final notifier = _RecordingNotifier();
    final worker = CarMessagingDispatchWorker(
      dio: dio,
      serverId: 'server-a',
      store: store,
      notifier: notifier,
      now: () => DateTime.fromMillisecondsSinceEpoch(5000),
    );

    final result = await worker.processReplies(const <String, String>{});

    expect(result.pending, isTrue);
    expect((await store.read()).replies, hasLength(1));
    expect(notifier.shown, isEmpty);
  });

  test('already-published final falls back to generic notification', () async {
    final store = CarMessagingStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: _MemoryFileStore(),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    const identity = SessionAttentionIdentity(
      serverId: 'server-a',
      directory: '/work/app',
      rootSessionId: 'session-a',
    );
    await store.upsertThread(
      const CarMessagingThread(
        identity: identity,
        title: 'Session',
        entries: <CarMessagingEntry>[
          CarMessagingEntry(
            role: CarMessagingRole.agent,
            text: 'Final answer',
            timestampEpochMs: 3,
            messageId: 'message-new',
          ),
        ],
        updatedAtEpochMs: 900,
      ),
    );
    final adapter = _ReplyAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter;
    final notifier = _RecordingNotifier();
    final worker = CarMessagingDispatchWorker(
      dio: dio,
      serverId: 'server-a',
      store: store,
      notifier: notifier,
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );

    expect(
      await worker.publishCompletion(
        sessionId: 'session-a',
        directory: '/work/app',
        title: 'Session',
      ),
      CarMessagingCompletionResult.notHandled,
    );
    final thread = (await store.read()).threads.single;
    expect(thread.entries, hasLength(1));
    expect(notifier.shown, isEmpty);
  });

  test('provably-unsent failures reset to queued for retry', () async {
    final store = CarMessagingStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: _MemoryFileStore(),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    const identity = SessionAttentionIdentity(
      serverId: 'server-a',
      directory: '/work/app',
      rootSessionId: 'session-a',
    );
    await store.enqueueReply(
      const CarMessagingReply(
        id: 'reply-a',
        identity: identity,
        text: 'Continue',
        createdAtEpochMs: 950,
      ),
    );
    final adapter = _ReplyAdapter(failConnect: true);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter;
    final notifier = _RecordingNotifier();
    final worker = CarMessagingDispatchWorker(
      dio: dio,
      serverId: 'server-a',
      store: store,
      notifier: notifier,
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final result = await worker.processReplies(const <String, String>{});

    expect(result.pending, isTrue);
    final reply = (await store.read()).replies.single;
    expect(reply.state, CarMessagingReplyState.queued);
    expect(reply.attempts, 1);
    expect(notifier.failures, isEmpty);
  });

  test('server rejection fails closed with a visible failure', () async {
    final store = CarMessagingStore(
      keyStorage: _MemoryKeyStorage(),
      fileStore: _MemoryFileStore(),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    const identity = SessionAttentionIdentity(
      serverId: 'server-a',
      directory: '/work/app',
      rootSessionId: 'session-a',
    );
    await store.enqueueReply(
      const CarMessagingReply(
        id: 'reply-a',
        identity: identity,
        text: 'Continue',
        createdAtEpochMs: 950,
      ),
    );
    final adapter = _ReplyAdapter(rejectPost: true);
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter;
    final notifier = _RecordingNotifier();
    final worker = CarMessagingDispatchWorker(
      dio: dio,
      serverId: 'server-a',
      store: store,
      notifier: notifier,
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final result = await worker.processReplies(const <String, String>{});

    expect(result.pending, isFalse);
    expect((await store.read()).replies, isEmpty);
    expect(notifier.failures, hasLength(1));
  });
}
