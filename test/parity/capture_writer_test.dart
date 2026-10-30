import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'capture_writer.dart';

void _writer(List<Object> args) {
  final reply = args[0] as SendPort;
  final path = args[1] as String;
  final value = args[2] as int;
  final start = ReceivePort();
  reply.send(['ready', start.sendPort]);
  start.first.then((_) {
    try {
      writeParityCapture(File(path), Uint8List.fromList([value]));
      reply.send(['written', value]);
    } on FileSystemException {
      reply.send(['rejected', value]);
    } finally {
      start.close();
    }
  });
}

void main() {
  test(
    'concurrent captures cannot replace one another',
    () async {
      final directory = Directory.systemTemp.createTempSync('parity-race-');
      final result = ReceivePort();
      final events = StreamIterator<dynamic>(result);
      final isolates = <Isolate>[];
      addTearDown(() async {
        for (final isolate in isolates) {
          isolate.kill(priority: Isolate.immediate);
        }
        await events.cancel();
        result.close();
        directory.deleteSync(recursive: true);
      });
      final file = File('${directory.path}/capture.png');
      for (final value in [1, 2]) {
        isolates.add(
          await Isolate.spawn(_writer, [result.sendPort, file.path, value]),
        );
      }
      final starts = <SendPort>[];
      for (var i = 0; i < 2; i++) {
        expect(await events.moveNext(), isTrue);
        final event = events.current as List<dynamic>;
        expect(event[0], 'ready');
        starts.add(event[1] as SendPort);
      }
      for (final start in starts) {
        start.send(null);
      }
      final outcomes = <List<dynamic>>[];
      for (var i = 0; i < 2; i++) {
        expect(await events.moveNext(), isTrue);
        outcomes.add(events.current as List<dynamic>);
      }
      expect(outcomes.where((e) => e[0] == 'written'), hasLength(1));
      expect(outcomes.where((e) => e[0] == 'rejected'), hasLength(1));
      expect(file.readAsBytesSync(), [
        outcomes.singleWhere((e) => e[0] == 'written')[1],
      ]);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
