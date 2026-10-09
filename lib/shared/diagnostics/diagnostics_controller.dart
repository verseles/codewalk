import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

enum DiagnosticOperation {
  hostCatalogLoad,
  hostProbe,
  profileSave,
  profileRemove,
  preferencesLoad,
  preferencesSave,
  archiveLoad,
  archiveSave,
}

enum DiagnosticOutcome { success, failure, cancelled }

enum DiagnosticSeverity { info, warning, error }

final class DiagnosticEvent {
  const DiagnosticEvent._(
    this.timestamp,
    this.operation,
    this.outcome,
    this.severity,
    this.elapsedMs,
  );

  final DateTime timestamp;
  final DiagnosticOperation operation;
  final DiagnosticOutcome outcome;
  final DiagnosticSeverity severity;
  final int? elapsedMs;

  String serialize() => jsonEncode({
    'timestamp': timestamp.toIso8601String(),
    'operation': operation.name,
    'outcome': outcome.name,
    'severity': severity.name,
    if (elapsedMs != null) 'elapsedMs': elapsedMs,
  });
}

enum DiagnosticCopyResult { copied, truncated, failed, invalidated }

/// Only finite, application-owned vocabulary crosses this boundary. No raw
/// context, error, identifier or text can be submitted by a producer.
final class DiagnosticsController extends ChangeNotifier {
  DiagnosticsController({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const maxEvents = 1000;
  static const maxSerializedBytes = 256 * 1024;
  static const maxClipboardBytes = 64 * 1024;
  final DateTime Function() _now;
  final Queue<DiagnosticEvent> _events = Queue();
  final Queue<int> _sizes = Queue();
  int _bytes = 2;
  int _generation = 0;
  bool _enabled = false;
  bool _disposed = false;

  bool get enabled => _enabled && !_disposed;
  int get serializedBytes => _bytes;
  List<DiagnosticEvent> get events => List.unmodifiable(_events);

  void setEnabled(bool value) {
    if (_disposed || _enabled == value) return;
    _enabled = value;
    _clear();
    notifyListeners();
  }

  void clear() {
    if (_disposed) return;
    _clear();
    notifyListeners();
  }

  void _clear() {
    _generation++;
    _events.clear();
    _sizes.clear();
    _bytes = 2;
  }

  void record(
    DiagnosticOperation operation,
    DiagnosticOutcome outcome, {
    DiagnosticSeverity severity = DiagnosticSeverity.info,
    int? elapsedMs,
  }) {
    if (!enabled) return;
    final event = DiagnosticEvent._(
      _now().toUtc(),
      operation,
      outcome,
      severity,
      elapsedMs?.clamp(0, 86400000),
    );
    // Reserve a separator per event, bounding both JSON-array and line exports.
    final size = utf8.encode(event.serialize()).length + 1;
    while (_events.isNotEmpty &&
        (_events.length >= maxEvents || _bytes + size > maxSerializedBytes)) {
      _events.removeFirst();
      _bytes -= _sizes.removeFirst();
    }
    if (_bytes + size > maxSerializedBytes) return;
    _events.add(event);
    _sizes.add(size);
    _bytes += size;
    notifyListeners();
  }

  /// Filtering is finite too; clipboard writers never receive arbitrary input.
  Future<DiagnosticCopyResult> copyFiltered({
    required Future<void> Function(String) write,
    DiagnosticOperation? operation,
    DiagnosticOutcome? outcome,
    DiagnosticSeverity? severity,
  }) async {
    if (!enabled) return DiagnosticCopyResult.invalidated;
    final generation = _generation;
    final lines = <String>[];
    var bytes = 0;
    var truncated = false;
    for (final event in _events) {
      if ((operation != null && operation != event.operation) ||
          (outcome != null && outcome != event.outcome) ||
          (severity != null && severity != event.severity)) {
        continue;
      }
      final line = event.serialize();
      final size = utf8.encode(line).length + (lines.isEmpty ? 0 : 1);
      if (bytes + size > maxClipboardBytes) {
        truncated = true;
        break;
      }
      lines.add(line);
      bytes += size;
    }
    if (!enabled || generation != _generation) {
      return DiagnosticCopyResult.invalidated;
    }
    try {
      await write(lines.join('\n'));
      if (!enabled || generation != _generation) {
        return DiagnosticCopyResult.invalidated;
      }
      return truncated
          ? DiagnosticCopyResult.truncated
          : DiagnosticCopyResult.copied;
    } on Object {
      return !enabled || generation != _generation
          ? DiagnosticCopyResult.invalidated
          : DiagnosticCopyResult.failed;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _enabled = false;
    _clear();
    super.dispose();
  }
}
