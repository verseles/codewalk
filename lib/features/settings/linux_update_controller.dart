import 'package:flutter/foundation.dart';

import '../../shared/releases/linux_update.dart';
import '../../shared/releases/update_selector.dart';
import 'update_check_controller.dart';

final class LinuxUpdateController extends ChangeNotifier {
  LinuxUpdateController(
    this._installer, {
    UpdateCheckController? checks,
    Future<void> Function()? beforeRestart,
    Future<void> Function()? afterRestart,
  }) : _checks = checks,
       _lastChannel = checks?.channel,
       _beforeRestart = beforeRestart,
       _afterRestart = afterRestart {
    _checks?.addListener(_onCheckChanged);
  }
  final LinuxUpdateInstaller _installer;
  final UpdateCheckController? _checks;
  UpdateChannel? _lastChannel;
  final Future<void> Function()? _beforeRestart;
  final Future<void> Function()? _afterRestart;
  LinuxUpdateStatus _status = LinuxUpdateStatus.idle;
  LinuxUpdateFailure? _failure;
  UpdateCandidate? _candidate;
  double _progress = 0;
  bool _disposed = false;
  bool _restarting = false;

  LinuxUpdateStatus get status => _status;
  LinuxUpdateFailure? get failure => _failure;
  UpdateCandidate? get candidate => _candidate;
  double get progress => _progress;
  bool get busy => const {
    LinuxUpdateStatus.downloading,
    LinuxUpdateStatus.verifying,
    LinuxUpdateStatus.installing,
  }.contains(_status);

  void _onCheckChanged() {
    final checks = _checks;
    if (_disposed || checks == null) return;
    final changed = checks.channel != _lastChannel;
    _lastChannel = checks.channel;
    if (_status == LinuxUpdateStatus.failed &&
        (changed ||
            (checks.status != UpdateCheckStatus.checking &&
                checks.candidate?.tag != _candidate?.tag))) {
      _candidate = null;
      _failure = null;
      _progress = 0;
      _status = LinuxUpdateStatus.idle;
      notifyListeners();
    }
  }

  Future<void> install(UpdateCandidate candidate) async {
    if (_disposed || busy || _status == LinuxUpdateStatus.ready) return;
    _candidate = candidate;
    _failure = null;
    _status = LinuxUpdateStatus.verifying;
    notifyListeners();
    try {
      if (!await _installer.available()) {
        throw const LinuxUpdateException(LinuxUpdateFailure.unavailable);
      }
      if (_disposed) return;
      await _installer.install(
        candidate,
        onProgress: (status, progress) {
          if (_disposed) return;
          _status = status;
          _progress = progress;
          notifyListeners();
        },
      );
      if (_disposed) return;
      _status = LinuxUpdateStatus.ready;
    } on LinuxUpdateException catch (error) {
      if (_disposed) return;
      _failure = error.failure;
      _status = LinuxUpdateStatus.failed;
    } on Object {
      if (_disposed) return;
      _failure = LinuxUpdateFailure.install;
      _status = LinuxUpdateStatus.failed;
    }
    notifyListeners();
  }

  Future<bool> restart() async {
    if (_disposed || _status != LinuxUpdateStatus.ready || _restarting) {
      return false;
    }
    _restarting = true;
    var success = false;
    try {
      await _beforeRestart?.call();
      success = await _installer.restart();
      if (success) await _afterRestart?.call();
    } on Object {
      /* Keep the running app available. */
    }
    if (!_disposed) {
      _restarting = false;
      if (!success) _failure = LinuxUpdateFailure.restart;
      notifyListeners();
    }
    return success;
  }

  @override
  void dispose() {
    _disposed = true;
    _checks?.removeListener(_onCheckChanged);
    _installer.close();
    super.dispose();
  }
}
