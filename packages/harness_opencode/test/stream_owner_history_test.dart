import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'execution_replay_test.dart' show refOf;
import 'history_test_data.dart';
import 'session_reader_test.dart' show TestTransport, response;
import 'stream_owner_test.dart' show ScriptedConnection;

/// A session of [total] user messages, one item each, served newest first in
/// pages that continue through an opaque native cursor (the row offset).
final class PagedServer {
  PagedServer(this.session, this.total);
  final String session;
  final int total;
  final messageQueries = <Map<String, String>>[];
  Completer<void>? gate;
  int? failStatus;

  String id(int index) => 'msg_m$index';

  late final transport = TestTransport((request, _) async {
    final uri = Uri.parse(request.path);
    final tail = uri.pathSegments.last;
    if (tail == 'message') {
      messageQueries.add(uri.queryParameters);
      if (gate != null) await gate!.future;
      if (failStatus != null) {
        return response({'error': 'x'}, status: failStatus!);
      }
      final limit = int.parse(uri.queryParameters['limit']!);
      final offset = int.parse(uri.queryParameters['cursor'] ?? '0');
      final end = (offset + limit).clamp(0, total);
      return response({
        'data': [
          for (var i = offset; i < end; i++)
            message('m${total - 1 - i}', 'user', {'text': 'row'}),
        ],
        'cursor': {'previous': null, 'next': end < total ? '$end' : null},
      });
    }
    return response(switch (tail) {
      'active' => const {'data': <String, Object?>{}},
      'inbox' || 'permission' || 'form' => const {'data': <Object?>[]},
      _ => {
        'data': {
          'id': session,
          'title': 'Session',
          'projectID': 'global',
          'time': {'created': 1, 'updated': 1},
        },
      },
    });
  });
}

final class Owner {
  Owner(String session, {int total = 2000})
    : ref = refOf(session),
      server = PagedServer(session, total) {
    owner = OpenCodeStreamOwner(
      connection: connection,
      reader: OpenCodeSessionReader(server.transport, harness: historyHarness),
      store: store,
      harness: historyHarness,
      sourceVersion: '2.0.22',
      now: () => DateTime.utc(2026, 10, 14),
      delay: (_) async {},
    )..start();
  }

  final SessionRef ref;
  final PagedServer server;
  final connection = ScriptedConnection();
  final store = SessionStore(maxSessions: 8);
  late final OpenCodeStreamOwner owner;

  SessionState get state => store.read(ref)!;
  List<String?> get messages => [
    for (final item in state.timeline) openCodeMessageIdOf(item.id, ref),
  ];

  Future<void> settle() async {
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> open() async {
    owner.watch(ref);
    connection.connect(1);
    await settle();
  }
}

void main() {
  test('pages older history at limit 200 and stops at 500 resident', () async {
    final o = Owner('ses_paged');
    await o.open();
    expect(o.state.timeline, hasLength(200));
    expect(o.messages.last, 'msg_m1999');
    expect(o.owner.canLoadOlderHistory(o.ref), isTrue);

    expect(await o.owner.loadOlderHistory(o.ref), isTrue);
    expect(o.state.timeline, hasLength(400));
    expect(o.messages.first, 'msg_m1600');

    expect(await o.owner.loadOlderHistory(o.ref), isTrue);
    // The newest are never evicted: the window keeps m1500..m1999.
    expect(o.messages, [for (var i = 1500; i < 2000; i++) 'msg_m$i']);
    expect(o.state.hasMoreHistory, isTrue);

    // At the cap nothing more is read.
    expect(o.owner.canLoadOlderHistory(o.ref), isFalse);
    expect(await o.owner.loadOlderHistory(o.ref), isFalse);
    expect(o.server.messageQueries, [
      {'limit': '200', 'order': 'desc'},
      {'limit': '200', 'cursor': '200'},
      {'limit': '200', 'cursor': '400'},
    ]);
  });

  test('concurrent loads share one read', () async {
    final o = Owner('ses_flight');
    await o.open();
    o.server.gate = Completer<void>();
    final first = o.owner.loadOlderHistory(o.ref);
    final second = o.owner.loadOlderHistory(o.ref);
    expect(o.owner.canLoadOlderHistory(o.ref), isFalse);
    o.server.gate!.complete();
    expect(await first, isTrue);
    expect(await second, isFalse);
    expect(o.server.messageQueries, hasLength(2));
  });

  test('a page read before a reconnect is dropped', () async {
    final o = Owner('ses_stale');
    await o.open();
    o.server.gate = Completer<void>();
    final load = o.owner.loadOlderHistory(o.ref);
    await o.settle();
    o.connection.connect(2);
    o.server.gate!.complete();
    expect(await load, isFalse);
    await o.settle();
    // The new generation hydrated the newest 200; the old page never landed.
    expect(o.state.timeline, hasLength(200));
    expect(o.messages.first, 'msg_m1800');
  });

  test('a failed read keeps the window and the cursor', () async {
    final o = Owner('ses_fail');
    await o.open();
    final cursor = o.state.nextHistoryCursor;
    o.server.failStatus = 503;
    await expectLater(
      o.owner.loadOlderHistory(o.ref),
      throwsA(isA<OpenCodeSessionReadException>()),
    );
    expect(o.state.timeline, hasLength(200));
    expect(o.state.nextHistoryCursor, cursor);
    expect(o.owner.canLoadOlderHistory(o.ref), isTrue);
  });

  test('the end of history clears the cursor', () async {
    final o = Owner('ses_short', total: 300);
    await o.open();
    expect(await o.owner.loadOlderHistory(o.ref), isTrue);
    expect(o.state.timeline, hasLength(300));
    expect(o.state.nextHistoryCursor, isNull);
    expect(o.owner.canLoadOlderHistory(o.ref), isFalse);
  });

  test('a window trimmed in front stops paging', () async {
    final o = Owner('ses_trim');
    await o.open();
    await o.owner.loadOlderHistory(o.ref);
    await o.owner.loadOlderHistory(o.ref);
    expect(o.state.timeline, hasLength(500));
    // A live removal at the tail makes room, but the window lost its oldest
    // rows in front: the cursor would skip them, so paging stays stopped.
    o.store.apply(
      o.ref,
      ItemsRemoved(
        meta: EventMeta(
          owner: SessionOwner(o.ref),
          position: StreamPosition(
            id: o.owner.streamId,
            epoch: '1',
            seq: BigInt.from(99),
          ),
          receivedAt: DateTime.utc(2026, 10, 14),
          source: SourceProvenance(
            harness: historyHarness,
            version: '2.0.22',
            nativeType: 'test.removed',
          ),
        ),
        fromItemId: o.state.timeline.last.id,
      ),
    );
    expect(o.state.timeline, hasLength(499));
    expect(o.state.nextHistoryCursor, isNotNull);
    expect(o.owner.canLoadOlderHistory(o.ref), isFalse);
    expect(o.owner.olderHistoryTrimmed(o.ref), isTrue);
  });

  test('a window trimmed by the last page stays known as trimmed', () async {
    final o = Owner('ses_exhausted', total: 600);
    await o.open();
    expect(o.owner.olderHistoryTrimmed(o.ref), isFalse);
    await o.owner.loadOlderHistory(o.ref);
    await o.owner.loadOlderHistory(o.ref);
    // The last page ends the cursor and lost its oldest 100 rows to the cap.
    expect(o.state.nextHistoryCursor, isNull);
    expect(o.messages.first, 'msg_m100');
    expect(o.owner.olderHistoryTrimmed(o.ref), isTrue);
    // A removal that empties the window does not make the trim unknown.
    o.store.apply(
      o.ref,
      ItemsRemoved(
        meta: EventMeta(
          owner: SessionOwner(o.ref),
          position: StreamPosition(
            id: o.owner.streamId,
            epoch: '1',
            seq: BigInt.from(99),
          ),
          receivedAt: DateTime.utc(2026, 10, 14),
          source: SourceProvenance(
            harness: historyHarness,
            version: '2.0.22',
            nativeType: 'test.removed',
          ),
        ),
        fromItemId: o.state.timeline.first.id,
      ),
    );
    expect(o.state.timeline, isEmpty);
    expect(o.owner.olderHistoryTrimmed(o.ref), isTrue);
  });
}
