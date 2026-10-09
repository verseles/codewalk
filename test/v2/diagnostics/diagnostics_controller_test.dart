import 'dart:async';
import 'dart:convert';

import 'package:codewalk/shared/diagnostics/diagnostics_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled logging never evaluates its clock or keeps events', () {
    final logs = DiagnosticsController(now: () => throw StateError('clock'));
    logs.record(DiagnosticOperation.hostProbe, DiagnosticOutcome.failure);
    expect(logs.events, isEmpty);
    logs.dispose();
  });

  test(
    'retention, immutability, numeric bounds and disable are independent',
    () {
      final logs = DiagnosticsController(now: () => DateTime.utc(2026, 10, 9));
      logs.setEnabled(true);
      for (var i = 0; i < 1100; i++) {
        logs.record(
          DiagnosticOperation.hostProbe,
          DiagnosticOutcome.success,
          elapsedMs: i,
        );
      }
      expect(logs.events.length, DiagnosticsController.maxEvents);
      expect(logs.events.first.elapsedMs, 100);
      expect(
        logs.serializedBytes,
        lessThanOrEqualTo(DiagnosticsController.maxSerializedBytes),
      );
      final snapshot = logs.events;
      expect(() => snapshot.clear(), throwsUnsupportedError);
      logs.record(
        DiagnosticOperation.profileSave,
        DiagnosticOutcome.failure,
        elapsedMs: -1,
      );
      expect(logs.events.last.elapsedMs, 0);
      logs.setEnabled(false);
      expect(logs.events, isEmpty);
      expect(snapshot.length, 1000);
      logs.setEnabled(true);
      expect(logs.events, isEmpty);
      logs.dispose();
    },
  );

  test(
    'copy exports only selected typed records within its byte limit',
    () async {
      final logs = DiagnosticsController(now: () => DateTime.utc(2026, 10, 9));
      logs.setEnabled(true);
      for (var i = 0; i < 1000; i++) {
        logs.record(DiagnosticOperation.archiveLoad, DiagnosticOutcome.failure);
      }
      String? text;
      final result = await logs.copyFiltered(
        write: (value) async => text = value,
        operation: DiagnosticOperation.archiveLoad,
      );
      expect(result, DiagnosticCopyResult.truncated);
      expect(
        utf8.encode(text!).length,
        lessThanOrEqualTo(DiagnosticsController.maxClipboardBytes),
      );
      for (final line in text!.split('\n')) {
        final record = jsonDecode(line) as Map<String, dynamic>;
        expect(record.keys.toSet(), {
          'timestamp',
          'operation',
          'outcome',
          'severity',
        });
        expect(record['operation'], 'archiveLoad');
      }
      logs.dispose();
    },
  );

  test('pending copy cannot claim success after consent changes', () async {
    final logs = DiagnosticsController();
    logs.setEnabled(true);
    logs.record(DiagnosticOperation.hostProbe, DiagnosticOutcome.success);
    final gate = Completer<void>();
    final copy = logs.copyFiltered(write: (_) => gate.future);
    logs.setEnabled(false);
    logs.setEnabled(true);
    gate.complete();
    expect(await copy, DiagnosticCopyResult.invalidated);
    expect(
      await logs.copyFiltered(write: (_) async => throw StateError('secret')),
      DiagnosticCopyResult.failed,
    );
    logs.dispose();
  });
}
