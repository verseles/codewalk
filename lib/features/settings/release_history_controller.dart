import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../platform/storage/metadata_store.dart';
import '../../shared/diagnostics/diagnostics_controller.dart';
import '../../shared/releases/release_archive.dart';
import '../../shared/releases/release_source.dart';

final class ReleaseHistoryController extends ChangeNotifier {
  ReleaseHistoryController({
    required ReleaseSource source,
    required V2MetadataStore store,
    DateTime Function()? now,
    DiagnosticsController? diagnostics,
  }) : _source = source,
       _store = store,
       _now = now ?? DateTime.now,
       _diagnostics = diagnostics;

  static const cacheKey = 'cw2.releaseHistory.cache';
  static const maxCacheBytes = 512 * 1024;
  static const cacheTtl = Duration(hours: 1);
  final ReleaseSource _source;
  final V2MetadataStore _store;
  final DateTime Function() _now;
  final DiagnosticsController? _diagnostics;
  List<ReleaseArchiveEntry> _entries = const [];
  DateTime? _fetchedAt;
  Future<void>? _inFlight;
  ReleaseSourceTask? _task;
  bool _readCache = false;
  bool _disposed = false;
  int _generation = 0;
  bool _failed = false;
  bool _loading = false;

  List<ReleaseArchiveEntry> get entries => _entries;
  DateTime? get fetchedAt => _fetchedAt;
  bool get failed => _failed;
  bool get loading => _loading;
  bool get savedCopyAvailable => _entries.isNotEmpty;

  Future<void> load({bool forceRefresh = false}) {
    if (_disposed) return Future.value();
    // A manual refresh behind a cache-only load must still reach the source.
    final existing = _inFlight;
    if (existing != null) {
      if (!forceRefresh || _task != null) return existing;
      return existing.then((_) => load(forceRefresh: true));
    }
    final generation = _generation;
    final completion = Completer<void>();
    final pending = _inFlight = completion.future;
    // Reserve before notifications, so even a synchronous listener coalesces.
    unawaited(
      _load(forceRefresh, generation).then<void>(
        (_) {
          if (identical(_inFlight, pending)) _inFlight = null;
          completion.complete();
        },
        onError: (Object error, StackTrace trace) {
          if (identical(_inFlight, pending)) _inFlight = null;
          completion.completeError(error, trace);
        },
      ),
    );
    return pending;
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  Future<void> _load(bool forceRefresh, int generation) async {
    _loading = true;
    _failed = false;
    notifyListeners();
    try {
      if (!_readCache) {
        try {
          await _store.ensureSchema();
          if (!_current(generation)) return;
          final stored = await _store.read(cacheKey);
          if (!_current(generation)) return;
          _readCache = true;
          if (stored != null) {
            if (stored is! String ||
                stored.length > maxCacheBytes ||
                utf8.encode(stored).length > maxCacheBytes) {
              throw const FormatException('Invalid archive cache');
            }
            final envelope = jsonDecode(stored);
            if (envelope is! Map<String, dynamic> ||
                envelope.length != 2 ||
                envelope['body'] is! String ||
                envelope['fetchedAt'] is! String) {
              throw const FormatException('Invalid archive cache');
            }
            final body = envelope['body'] as String;
            if (utf8.encode(body).length > ReleaseSource.maxBodyBytes) {
              throw const FormatException('Oversized archive');
            }
            final date = DateTime.tryParse(envelope['fetchedAt'] as String);
            if (date == null || !date.isUtc) {
              throw const FormatException('Invalid archive timestamp');
            }
            final entries = parseReleaseArchive(body);
            if (!_current(generation)) return;
            _entries = entries;
            // Future timestamps retain usable notes but cannot confer freshness.
            _fetchedAt = date.isAfter(_now().toUtc()) ? null : date;
          }
        } on Object {
          if (!_current(generation)) return;
          _diagnostics?.record(
            DiagnosticOperation.archiveLoad,
            DiagnosticOutcome.failure,
            severity: DiagnosticSeverity.warning,
          );
        }
      }
      if (!_current(generation)) return;
      final at = _fetchedAt;
      final age = at == null ? null : _now().toUtc().difference(at);
      if (!forceRefresh &&
          age != null &&
          age >= Duration.zero &&
          age < cacheTtl) {
        return;
      }
      final task = _task = _source.start();
      final result = await task.result;
      if (!_current(generation)) return;
      if (result.failure != null || result.body == null) {
        throw const FormatException('Archive source unavailable');
      }
      final body = result.body!;
      if (utf8.encode(body).length > ReleaseSource.maxBodyBytes) {
        throw const FormatException('Oversized archive');
      }
      final entries = parseReleaseArchive(body);
      final versions = entries.map((entry) => entry.version).toSet();
      if (_entries.any((entry) => !versions.contains(entry.version))) {
        throw const FormatException('Shortened archive');
      }
      final now = _now().toUtc();
      final cache = jsonEncode({
        'body': body,
        'fetchedAt': now.toIso8601String(),
      });
      if (utf8.encode(cache).length > maxCacheBytes) {
        throw const FormatException('Oversized archive envelope');
      }
      if (!_current(generation)) return;
      // Once authorized, storage finishes independently of UI lifetime.
      try {
        await _store.write(cacheKey, cache);
      } on Object {
        if (_current(generation)) {
          _diagnostics?.record(
            DiagnosticOperation.archiveSave,
            DiagnosticOutcome.failure,
            severity: DiagnosticSeverity.error,
          );
        }
        rethrow;
      }
      if (!_current(generation)) return;
      _entries = entries;
      _fetchedAt = now;
      _diagnostics?.record(
        DiagnosticOperation.archiveSave,
        DiagnosticOutcome.success,
      );
      _diagnostics?.record(
        DiagnosticOperation.archiveLoad,
        DiagnosticOutcome.success,
      );
    } on Object {
      if (!_current(generation)) return;
      _failed = true;
      _diagnostics?.record(
        DiagnosticOperation.archiveLoad,
        DiagnosticOutcome.failure,
        severity: DiagnosticSeverity.error,
      );
    } finally {
      if (_current(generation)) {
        _task = null;
        _loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _task?.cancel();
    _source.close();
    super.dispose();
  }
}
