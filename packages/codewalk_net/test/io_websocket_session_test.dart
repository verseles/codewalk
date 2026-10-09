import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:codewalk_net/codewalk_net.dart';
import 'package:codewalk_net/src/io_websocket_session.dart';
import 'package:test/test.dart';

/// Controllable flush is needed to exercise queue saturation without relying on
/// kernel TCP buffer sizes or scheduler timing in the loopback tests.
final class ControlledSocket extends Stream<Uint8List> implements Socket {
  final input = StreamController<Uint8List>();
  final writes = <List<int>>[];
  final flushSignal = Completer<void>();
  bool destroyed = false;

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => input.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  void add(List<int> data) => writes.add(List.of(data));
  @override
  Future<void> flush() => flushSignal.future;
  @override
  void destroy() {
    if (destroyed) return;
    destroyed = true;
    if (!flushSignal.isCompleted) {
      flushSignal.completeError(const SocketException('closed'));
    }
    unawaited(input.close());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unused socket operation.');
}

IoWebSocketSession session(ControlledSocket socket, {int maxMessages = 256}) {
  final result = IoWebSocketSession(
    socket,
    maxMessageBytes: 1,
    maxQueuedBytes: 1024,
    maxQueuedMessages: maxMessages,
    writeTimeout: const Duration(seconds: 2),
    closeTimeout: const Duration(milliseconds: 200),
    onClosed: () {},
  );
  addTearDown(() {
    result.fail(TransportFailure.closed);
  });
  return result;
}

Future<void> waitWrite(ControlledSocket socket) async {
  while (socket.writes.isEmpty) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'local Close still replies to Ping until a peer Close is received',
    () async {
      final socket = ControlledSocket()..flushSignal.complete();
      final connection = session(socket);
      final stream = connection.messages.listen((_) {}, onError: (Object _) {});
      addTearDown(stream.cancel);
      final closing = connection.close();
      await waitWrite(socket);
      socket.input.add(Uint8List.fromList([0x89, 1, 42]));
      while (socket.writes.length < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(socket.writes.last[0] & 15, 10);
      socket.input.add(Uint8List.fromList([0x88, 2, 3, 232]));
      socket.input.add(Uint8List.fromList([0x89, 1, 43]));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(socket.writes.length, 2);
      await socket.input.close();
      await closing;
    },
  );
  test(
    'small data cap still permits pong and a shared bounded close handshake',
    () async {
      final socket = ControlledSocket();
      final connection = session(socket);
      final stream = connection.messages.listen((_) {}, onError: (Object _) {});
      addTearDown(stream.cancel);
      socket.input.add(Uint8List.fromList([0x89, 3, 1, 2, 3]));
      await waitWrite(socket);
      expect(socket.writes.first[0] & 15, 10);
      expect(socket.writes.first[1] & 127, 3);
      socket.flushSignal.complete();
      final first = connection.close();
      expect(identical(first, connection.close()), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(socket.writes.last[0] & 15, 8);
      expect(socket.writes.last[1] & 127, 2);
      expect(connection.isClosed, isFalse);
      socket.input.add(Uint8List.fromList([0x88, 2, 3, 232]));
      await socket.input.close();
      await first;
      expect(connection.isClosed, isTrue);
    },
  );

  test(
    'pong queue saturation fails closed instead of silently dropping ping',
    () async {
      final socket = ControlledSocket();
      final connection = session(socket, maxMessages: 1);
      final error = expectLater(
        connection.messages,
        emitsError(
          isA<TransportException>().having(
            (e) => e.failure,
            'queue',
            TransportFailure.bufferOverflow,
          ),
        ),
      );
      final sending = connection.sendBytes([1]);
      final sendFailure = expectLater(
        sending,
        throwsA(isA<TransportException>()),
      );
      await waitWrite(socket);
      socket.input.add(Uint8List.fromList([0x89, 1, 42]));
      await error;
      await sendFailure;
      expect(socket.destroyed, isTrue);
    },
  );
}
