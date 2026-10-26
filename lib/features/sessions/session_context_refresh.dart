import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';

import '../../shared/sessions/session_catalog_source.dart';

/// The head rows last read for one open project context the list does not
/// show, and whether they are all of its sessions.
final class SessionContextSnapshot {
  SessionContextSnapshot(
    Iterable<SessionSummary> rows, {
    required this.complete,
  }) : rows = List.unmodifiable(rows);
  final List<SessionSummary> rows;
  final bool complete;
}

/// Re-reads the head page of the open contexts the list does not show, one
/// at a time, so their counts and recent sessions follow the server without
/// a request per row or per event.
///
/// A pass is coalesced: requests during a pass become one more pass, and
/// passes start at least [minInterval] apart. Three failed passes in a row
/// stop the automatic passes until the next explicit [refresh].
final class SessionContextRefresh {
  SessionContextRefresh({
    required this.read,
    required this.publish,
    this.minInterval = const Duration(seconds: 10),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Starts the head read of one context, or throws when the server is not
  /// ready.
  final SessionCatalogTask Function(String directory) read;

  /// Receives a context's fresh head rows; it drops them when the context
  /// was closed or the server changed meanwhile.
  final void Function(String directory, SessionContextSnapshot snapshot)
  publish;
  final Duration minInterval;
  final DateTime Function() _now;

  /// The contexts each pass reads, in order.
  List<String> _directories = const [];
  int _token = 0;
  bool _running = false;
  bool _again = false;
  int _failures = 0;
  DateTime? _earliest;
  Timer? _timer;
  SessionCatalogTask? _task;

  /// The open contexts the list does not show. A context new to the set is
  /// read at once; one that left it stops being read.
  void track(Iterable<String> directories, {Set<String> known = const {}}) {
    final next = directories.toList(growable: false);
    final fresh = next.any(
      (d) => !_directories.contains(d) && !known.contains(d),
    );
    _directories = next;
    if (fresh) refresh();
  }

  /// A pass the user or a context change asked for: it lifts a stop.
  void refresh() {
    _failures = 0;
    _schedule(immediate: true);
  }

  /// A change the server reported: a pass within the interval.
  void changed() {
    if (_failures >= 3) return;
    _schedule(immediate: false);
  }

  void _schedule({required bool immediate}) {
    if (_directories.isEmpty) return;
    if (_running) {
      _again = true;
      return;
    }
    if (_timer != null) return;
    final now = _now();
    final earliest = _earliest;
    final wait = immediate || earliest == null || !now.isBefore(earliest)
        ? Duration.zero
        : earliest.difference(now);
    final token = _token;
    _timer = Timer(wait, () {
      _timer = null;
      if (token == _token) unawaited(_pass(token));
    });
  }

  Future<void> _pass(int token) async {
    _running = true;
    _again = false;
    var failed = false;
    try {
      for (final directory in _directories.toList()) {
        if (token != _token) return;
        if (!_directories.contains(directory)) continue;
        final SessionCatalogTask task;
        try {
          task = read(directory);
        } on Object {
          failed = true;
          break;
        }
        _task = task;
        try {
          final page = await task.result;
          if (token != _token) return;
          publish(
            directory,
            SessionContextSnapshot(
              page.items,
              // A 2.0.22 page keeps a next cursor even at the end, so a short
              // page ends the list too.
              complete: page.nextCursor == null || page.items.length < 50,
            ),
          );
        } on Object {
          if (token != _token) return;
          failed = true;
        } finally {
          if (identical(_task, task)) _task = null;
        }
      }
    } finally {
      if (token == _token) {
        _running = false;
        _failures = failed ? _failures + 1 : 0;
        _earliest = _now().add(minInterval);
        if (_again && _failures < 3) _schedule(immediate: false);
      }
    }
  }

  /// Stops every pass and read: the server or its binding changed.
  void cancel() {
    _token++;
    _timer?.cancel();
    _timer = null;
    _task?.cancel();
    _task = null;
    _running = false;
    _again = false;
    _failures = 0;
    _earliest = null;
    _directories = const [];
  }
}
