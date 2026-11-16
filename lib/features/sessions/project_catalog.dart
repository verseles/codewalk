import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';

import '../../shared/sessions/session_catalog_source.dart';

/// One ephemeral project listing for the selected endpoint. All surfaces share
/// this read; changing the endpoint retires both its data and pending replies.
final class ProjectCatalog {
  ProjectCatalog({
    required this.notify,
    this.refreshInterval = const Duration(seconds: 10),
  });

  final void Function() notify;
  final Duration refreshInterval;
  SessionCatalogSource? _source;
  SessionCatalogRead<List<ProjectInfo>>? _task;
  Future<List<ProjectInfo>>? _pending;
  List<ProjectInfo> _entries = const [];
  Map<String, ProjectInfo> _byDirectory = const {};
  int _generation = 0;
  bool _loaded = false;
  bool _dirty = false;
  Timer? _timer;
  DateTime? _lastRead;

  List<ProjectInfo> get entries => _entries;
  Uri? iconAt(String directory) => _byDirectory[directory]?.icon;

  Uri? iconFor(ProjectRef? project) => project?.host == _source?.harness.host
      ? _byDirectory[project?.canonicalDirectory]?.icon
      : null;

  void bind(SessionCatalogSource? source) {
    if (identical(source, _source)) return;
    _generation++;
    _task?.cancel();
    _task = null;
    _pending = null;
    _timer?.cancel();
    _timer = null;
    _dirty = _loaded = false;
    _lastRead = null;
    _entries = const [];
    _byDirectory = const {};
    _source = source;
    if (source != null) unawaited(read());
  }

  Future<List<ProjectInfo>> read({bool refresh = false}) {
    final source = _source;
    if (source == null) return Future.value(const []);
    if (_pending case final pending?) return pending;
    if (_loaded && !refresh) return Future.value(_entries);
    _timer?.cancel();
    _timer = null;
    _dirty = false;
    _lastRead = DateTime.now();
    final generation = _generation;
    return _pending = Future.microtask(() => _read(source, generation));
  }

  Future<List<ProjectInfo>> _read(
    SessionCatalogSource source,
    int generation,
  ) async {
    if (generation != _generation) return const [];
    try {
      final task = _task = source.projects();
      final entries = await task.result;
      if (generation != _generation) return const [];
      final seen = <String>{};
      _entries = List.unmodifiable(
        entries.where(
          (entry) =>
              entry.ref.host == source.harness.host &&
              seen.add(entry.ref.canonicalDirectory),
        ),
      );
      _byDirectory = {
        for (final entry in _entries) entry.ref.canonicalDirectory: entry,
      };
    } on Object {
      // Optional metadata failure keeps the last successful listing. Retry on
      // an explicit refresh or later event, never on every catalog notification.
    } finally {
      if (generation == _generation) {
        _task = null;
        _pending = null;
        _loaded = true;
        if (_dirty) _schedule();
        notify();
      }
    }
    return generation == _generation ? _entries : const [];
  }

  /// A burst of project events needs one authoritative re-read. An event that
  /// arrives during a read remains dirty until the following pass.
  void changed() {
    if (_source == null) return;
    _dirty = true;
    if (_pending == null) _schedule();
  }

  void _schedule() {
    if (_timer != null) return;
    final elapsed = DateTime.now().difference(_lastRead ?? DateTime.now());
    final delay = refreshInterval - elapsed;
    _timer = Timer(delay.isNegative ? Duration.zero : delay, () {
      _timer = null;
      unawaited(read(refresh: true));
    });
  }

  void dispose() => bind(null);
}
