import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../platform/storage/metadata_store.dart';
import 'update_check_controller.dart';

/// Owns the automatic update policy for the lifetime of the app graph.
final class UpdateScheduler extends ChangeNotifier {
  UpdateScheduler({
    required UpdateCheckController checks,
    required V2MetadataStore store,
    DateTime Function()? clock,
  }) : _checks = checks,
       _store = store,
       _clock = clock ?? DateTime.now;

  static const preferenceKey = 'cw2.updates.checkOnOpen';
  final UpdateCheckController _checks;
  final V2MetadataStore _store;
  final DateTime Function() _clock;
  Timer? _timer;
  Future<void>? _initializing;
  DateTime? _lastSettingsCheck;
  bool _enabled = true;
  bool _disposed = false;

  bool get enabled => _enabled;

  Future<void> start() => _initializing ??= _start();

  Future<void> _start() async {
    try {
      await _store.ensureSchema();
      final saved = await _store.read(preferenceKey);
      if (saved is bool) _enabled = saved;
    } on Object {
      // The v1 default is enabled if the preference cannot be read.
    }
    if (_disposed) return;
    notifyListeners();
    if (_enabled) {
      unawaited(
        _checks.check(silent: true, force: false).whenComplete(_resetTimer),
      );
    }
  }

  Future<bool> setEnabled(bool value) async {
    await start();
    if (_disposed || _enabled == value) return !_disposed;
    try {
      await _store.write(preferenceKey, value);
    } on Object {
      return false;
    }
    if (_disposed) return false;
    _enabled = value;
    _resetTimer();
    notifyListeners();
    return true;
  }

  Future<void> settingsOpened() async {
    await start();
    if (_disposed) return;
    final now = _clock();
    final last = _lastSettingsCheck;
    if (last != null &&
        !now.isBefore(last) &&
        now.difference(last) < const Duration(minutes: 20)) {
      return;
    }
    _lastSettingsCheck = now;
    await _checks.check(silent: true);
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = null;
    if (!_disposed && _enabled && _checks.supported) {
      const hour = Duration(hours: 1);
      final now = _clock();
      final last = _checks.lastSuccessfulCheck;
      final remaining = last == null || now.isBefore(last)
          ? hour
          : hour - now.difference(last);
      // A Settings check may have refreshed the cache since this timer was
      // armed. Schedule its actual expiry instead of skipping a whole hour.
      _timer = Timer(remaining > Duration.zero ? remaining : hour, () {
        unawaited(
          _checks.check(silent: true, force: false).whenComplete(_resetTimer),
        );
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
