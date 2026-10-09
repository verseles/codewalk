import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';

import '../hosts/hosts_controller.dart';

/// A capture requests confirmation; it never establishes trust or starts traffic.
class PairingController extends ChangeNotifier {
  PairingController({
    required this.pairing,
    required this.hosts,
    required this.qr,
  });
  final EndpointPairing pairing;
  final HostsController hosts;
  final QrInput qr;
  PairingCandidate? candidate;
  EndpointProfile? target;
  PairingResult? receipt;
  bool busy = false;
  bool storageError = false;
  QrInputFailure? captureError;
  PairingTask? _task;
  QrInputTask? _capture;
  int _generation = 0;
  bool _disposed = false;
  bool _attempted = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void cancel() {
    _generation++;
    _task?.cancel();
    _task = null;
    _capture?.cancel();
    _capture = null;
    busy = false;
  }

  void input(String text, {EndpointProfile? profile}) {
    cancel();
    target = profile;
    receipt = null;
    storageError = false;
    captureError = null;
    _attempted = false;
    candidate = pairing.parse(text);
    if (candidate == null ||
        (profile != null && candidate!.endpoint != profile.endpoint)) {
      candidate = null;
      receipt = const PairingResult(PairingStatus.invalidInput);
    }
    _notify();
  }

  void empty({EndpointProfile? profile}) {
    cancel();
    target = profile;
    candidate = null;
    receipt = null;
    _attempted = false;
    storageError = false;
    captureError = null;
    _notify();
  }

  Future<void> capture({required bool camera}) async {
    if (busy || _disposed) return;
    final profile = target;
    cancel();
    final generation = _generation;
    busy = true;
    captureError = null;
    _notify();
    try {
      final capture = _capture = camera ? qr.camera() : qr.image();
      final text = await capture.result;
      if (_disposed || generation != _generation) return;
      if (text != null) input(text, profile: profile);
    } on QrInputException catch (error) {
      if (!_disposed && generation == _generation) captureError = error.failure;
    } on Object {
      if (!_disposed && generation == _generation) {
        captureError = QrInputFailure.unreadable;
      }
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        _capture = null;
        _notify();
      }
    }
  }

  Future<void> confirm() async {
    final selected = candidate;
    if (_disposed || busy || selected == null || _attempted) return;
    _attempted = true;
    cancel();
    final generation = _generation;
    busy = true;
    receipt = null;
    _notify();
    final task = _task = pairing.redeem(selected);
    final result = await task.result;
    if (_disposed || generation != _generation) return;
    _task = null;
    receipt = result;
    busy = false;
    _notify();
  }

  void close() {
    cancel();
    candidate = null;
    receipt = null;
    target = null;
  }

  Future<void> renew(EndpointProfile profile) async {
    if (_disposed || busy) return;
    empty(profile: profile);
    final generation = _generation;
    busy = true;
    _notify();
    try {
      final credential = await hosts.repository.readCredential(profile);
      if (_disposed || generation != _generation) return;
      if (credential == null) {
        receipt = const PairingResult(PairingStatus.rejected);
        return;
      }
      final task = _task = pairing.renew(profile.endpoint, credential);
      final result = await task.result;
      if (!_disposed && generation == _generation) receipt = result;
    } on Object {
      if (!_disposed && generation == _generation) storageError = true;
    } finally {
      if (!_disposed && generation == _generation) {
        _task = null;
        busy = false;
        _notify();
      }
    }
  }

  Future<bool> save(String label) async {
    final credential = receipt?.credential;
    final endpoint = target?.endpoint ?? candidate?.endpoint;
    if (_disposed || busy || credential == null || endpoint == null) {
      return false;
    }
    final generation = _generation;
    busy = true;
    storageError = false;
    _notify();
    var saved = false;
    try {
      final profile = target;
      if (profile != null) {
        saved = await hosts.repair(
          profile,
          credential,
          isCurrent: () => !_disposed && generation == _generation,
        );
      } else {
        final assessment = await hosts.probe(endpoint, credential.secret);
        if (!_disposed &&
            generation == _generation &&
            assessment?.canUse == true) {
          saved = await hosts.addCredential(
            endpoint,
            label,
            credential,
            assessment!,
          );
        }
      }
      if (saved && !_disposed && generation == _generation) {
        receipt = null;
        candidate = null;
        await hosts.load();
      }
      if (!_disposed && generation == _generation) storageError = !saved;
      return saved && !_disposed && generation == _generation;
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
    candidate = null;
    receipt = null;
    super.dispose();
  }
}
