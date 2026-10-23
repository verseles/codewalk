import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../platform/storage/metadata_store.dart';
import '../../shared/releases/app_version.dart';
import '../../shared/releases/release_source.dart';
import '../../shared/releases/update_selector.dart';

enum UpdateCheckStatus { idle, checking, upToDate, available, failed }

/// A manual CodeWalk update check: it never downloads or installs anything.
///
/// The channel defaults to stable; beta is an explicit, persisted opt-in.
/// A null [target] means this platform has no CodeWalk 2 update route.
final class UpdateCheckController extends ChangeNotifier {
  UpdateCheckController({
    required ReleaseSource source,
    required V2MetadataStore store,
    required Future<String> Function() installedVersion,
    required this.target,
  }) : _source = source,
       _store = store,
       _installedVersion = installedVersion;

  static const channelKey = 'cw2.updates.channel';
  final ReleaseSource _source;
  final V2MetadataStore _store;
  final Future<String> Function() _installedVersion;
  final UpdateTarget? target;
  UpdateChannel _channel = UpdateChannel.stable;
  UpdateCheckStatus _status = UpdateCheckStatus.idle;
  UpdateCandidate? _candidate;
  String? _installed;
  ReleaseSourceTask? _task;
  Future<void>? _restoring;
  int _generation = 0;
  bool _disposed = false;

  UpdateChannel get channel => _channel;
  UpdateCheckStatus get status => _status;
  UpdateCandidate? get candidate => _candidate;
  String? get installedVersion => _installed;
  bool get supported => target != null;

  /// Reads the saved channel once; later calls reuse the same read.
  Future<void> restore() => _restoring ??= _restore();

  Future<void> _restore() async {
    try {
      await _store.ensureSchema();
      final saved = await _store.read(channelKey);
      if (!_disposed &&
          saved == UpdateChannel.beta.name &&
          _channel != UpdateChannel.beta) {
        _channel = UpdateChannel.beta;
        notifyListeners();
      }
    } on Object {
      // An unreadable preference keeps the stable default.
    }
  }

  Future<void> setChannel(UpdateChannel value) async {
    await restore();
    if (_disposed || value == _channel) return;
    _channel = value;
    // A result for the other channel no longer applies.
    _cancel();
    _status = UpdateCheckStatus.idle;
    _candidate = null;
    notifyListeners();
    try {
      await _store.write(channelKey, value.name);
    } on Object {
      // The choice still applies to this session.
    }
  }

  Future<void> check() async {
    final target = this.target;
    if (_disposed || target == null || _status == UpdateCheckStatus.checking) {
      return;
    }
    // Claim the check before any await, so a second tap cannot start another.
    final generation = ++_generation;
    _status = UpdateCheckStatus.checking;
    _candidate = null;
    notifyListeners();
    await restore();
    if (!_current(generation)) return;
    final channel = _channel;
    var outcome = UpdateCheckStatus.failed;
    UpdateCandidate? found;
    try {
      final installed = await _installedVersion();
      final current = AppVersion.tryParse(installed);
      if (!_current(generation)) return;
      _installed = installed;
      if (current != null) {
        final task = _task = _source.start();
        final result = await task.result;
        if (!_current(generation)) return;
        _task = null;
        final body = result.body;
        if (body != null) {
          found = selectUpdate(
            releases: jsonDecode(body),
            channel: channel,
            current: current,
            target: target,
          );
          outcome = found == null
              ? UpdateCheckStatus.upToDate
              : UpdateCheckStatus.available;
        }
      }
    } on Object {
      outcome = UpdateCheckStatus.failed;
    }
    if (!_current(generation)) return;
    _status = outcome;
    _candidate = found;
    notifyListeners();
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  void _cancel() {
    _generation++;
    _task?.cancel();
    _task = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel();
    _source.close();
    super.dispose();
  }
}
