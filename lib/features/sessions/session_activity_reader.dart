import 'dart:async';

import '../../shared/sessions/session_activity.dart';
import '../../shared/sessions/session_catalog_source.dart';

/// Reads the activity of the selected profile: the running sessions and the
/// sessions of the shown project group that wait for the user.
///
/// One read runs at a time; a request during it becomes one more read. A read
/// of a profile that was left is dropped, a request the new profile made
/// during it still runs, and a failure leaves its part unknown without
/// touching the rows.
class SessionActivityReader {
  SessionActivityReader({
    required this.source,
    required this.directory,
    required this.notify,
  });

  /// The selected profile's source, or null while there is none or the list
  /// is gone.
  final SessionCatalogSource? Function() source;

  /// The location whose pending permission requests and forms are read.
  final String? Function() directory;

  /// Tells the list's listeners that the activity changed.
  final void Function() notify;

  /// The activity the endpoint last reported.
  SessionActivity activity = const SessionActivity();

  /// Whether a read is in flight.
  bool get reading => _reading;
  bool _reading = false;
  bool _again = false;

  /// Forgets the activity and a request of the profile that was left.
  void reset() {
    activity = const SessionActivity();
    _again = false;
  }

  Future<void> sync() async {
    final source = this.source();
    if (source == null) return;
    if (_reading) {
      _again = true;
      return;
    }
    _reading = true;
    try {
      do {
        _again = false;
        final activity = await source.activity(directory: directory());
        if (!identical(source, this.source())) return;
        this.activity = activity;
        notify();
      } while (_again);
    } finally {
      _reading = false;
      if (_again && !identical(source, this.source())) {
        _again = false;
        unawaited(sync());
      }
    }
  }
}
