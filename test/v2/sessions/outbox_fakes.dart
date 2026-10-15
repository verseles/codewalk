import 'dart:async';
import 'dart:convert';

import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:flutter_test/flutter_test.dart';

/// Map-backed store whose writes can fail before or after committing.
class OutboxStore implements PayloadStore {
  final values = <String, String>{};
  final unreadable = <String>{};
  bool failWrite = false;
  bool commitThenThrow = false;
  int writes = 0;
  @override
  Future<bool> contains(String key) async =>
      values.containsKey(key) || unreadable.contains(key);
  @override
  Future<String?> read(String key) async =>
      unreadable.contains(key) ? null : values[key];
  @override
  Future<PayloadWriteResult> write(String key, String value) async {
    writes++;
    if (failWrite) throw StateError('disk full');
    final same = values[key] == value;
    values[key] = value;
    if (commitThenThrow) throw StateError('failed after rename');
    return same ? PayloadWriteResult.unchanged : PayloadWriteResult.written;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// Posts go to [respond]; reads go to [read] and inbox changes to [change],
/// which fail unless set.
final class OutboxTransport implements EndpointHttpTransport {
  OutboxTransport(this.respond, {this.read, this.change});
  FutureOr<TransportResponse> Function(Map<String, Object?> body) respond;
  FutureOr<TransportResponse> Function(Uri uri)? read;
  FutureOr<TransportResponse> Function(TransportRequest request)? change;
  final changes = <TransportRequest>[];
  final bodies = <Map<String, Object?>>[];
  final reads = <Uri>[];
  final raw = <String>[];
  void Function()? onSend;
  @override
  Uri endpoint = Uri.parse('http://127.0.0.1/');
  @override
  bool isClosed = false;
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    RequestCancellation? cancellation,
  }) async {
    if (request.method == 'GET') {
      final uri = Uri.parse(request.path);
      reads.add(uri);
      return (read ?? (_) => fail('no read expected'))(uri);
    }
    if (request.method != 'POST') {
      changes.add(request);
      return (change ?? (_) => fail('no change expected'))(request);
    }
    onSend?.call();
    raw.add(utf8.decode(request.body!));
    final body = jsonDecode(raw.last) as Map<String, Object?>;
    bodies.add(body);
    return respond(body);
  }

  @override
  void close() => isClosed = true;
}

TransportResponse outboxJson(Object? body, {int status = 200}) =>
    TransportResponse(
      statusCode: status,
      headers: {
        'content-type': ['application/json'],
      },
      body: Stream.value(utf8.encode(jsonEncode(body))),
      cancel: () {},
    );

/// A native 2.0.22 session reduced to what reconciliation reads: a same-id
/// POST returns the original admission, the inbox lists pending input and
/// promotion moves it to history.
final class OutboxServer {
  OutboxServer() {
    transport = OutboxTransport(_post, read: _read, change: _change);
  }

  /// Answers a DELETE or PATCH; null applies it like 2.0.22.
  FutureOr<TransportResponse> Function(TransportRequest request)? changeAnswer;

  /// Runs when a DELETE or PATCH reaches the server, before it applies.
  void Function()? beforeChange;
  late final OutboxTransport transport;
  final inbox = <Map<String, Object?>>[];
  final history = <Map<String, Object?>>[];

  /// False: the request is lost before the server; true otherwise.
  bool reachServer = true;

  /// The server admits, but its response is lost.
  bool loseResponse = false;
  int? failReads;
  String? next;
  void Function()? onPost;

  Map<String, Object?> row(Map<String, Object?> body) => {
    'id': body['id'],
    'sessionID': 'ses_one',
    'time': {'created': 1},
    'type': 'user',
    'payload': {'text': body['text']},
    'delivery': body['delivery'],
  };

  void promote(String id) {
    final row = inbox.singleWhere((r) => r['id'] == id);
    inbox.remove(row);
    history.add({
      'id': id,
      'time': row['time'],
      'text': (row['payload']! as Map)['text'],
      'type': 'user',
    });
  }

  FutureOr<TransportResponse> _post(Map<String, Object?> body) {
    onPost?.call();
    if (!reachServer) {
      throw const TransportException(TransportFailure.timeout);
    }
    var admitted = inbox.where((r) => r['id'] == body['id']).firstOrNull;
    if (admitted == null && !history.any((r) => r['id'] == body['id'])) {
      inbox.add(admitted = row(body));
    }
    if (loseResponse) {
      throw const TransportException(TransportFailure.timeout);
    }
    return outboxJson({'data': admitted ?? row(body)});
  }

  /// 2.0.22: a DELETE of a delivered or unknown id is a 204 no-op; a PATCH
  /// of a delivered id is a 409.
  FutureOr<TransportResponse> _change(TransportRequest request) {
    beforeChange?.call();
    if (changeAnswer case final answer?) return answer(request);
    final id = Uri.parse(request.path).pathSegments.last;
    final row = inbox.where((r) => r['id'] == id).firstOrNull;
    if (request.method == 'DELETE') {
      if (row != null) inbox.remove(row);
      return outboxEmpty(204);
    }
    if (row == null) return outboxJson({'_tag': 'ConflictError'}, status: 409);
    row['delivery'] =
        (jsonDecode(utf8.decode(request.body!)) as Map)['delivery'];
    return outboxEmpty(204);
  }

  TransportResponse _read(Uri uri) {
    if (failReads case final status?) return outboxJson({}, status: status);
    if (uri.pathSegments.last == 'inbox') return outboxJson({'data': inbox});
    return outboxJson({
      'data': history.reversed.take(200).toList(),
      // Each page points further back.
      'cursor': {
        'previous': null,
        'next': next == null ? null : '$next${transport.reads.length}',
      },
    });
  }
}

TransportResponse outboxEmpty(int status) => TransportResponse(
  statusCode: status,
  headers: const {},
  body: const Stream.empty(),
  cancel: () {},
);
