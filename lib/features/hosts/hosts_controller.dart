import 'dart:async';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';

class HostsController extends ChangeNotifier {
  HostsController({
    required this.repository,
    required this.prober,
    String Function()? createId,
    DateTime Function()? now,
  }) : _createId = createId ?? _id,
       _now = now ?? DateTime.now;
  final EndpointProfileRepository repository;
  final EndpointProber prober;
  final String Function() _createId;
  List<EndpointProfile> _profiles = const [];
  List<EndpointProfile> get profiles => _profiles;
  final Map<String, EndpointAssessment> _assessments = {};
  Map<String, EndpointAssessment> get assessments =>
      Map.unmodifiable(_assessments);
  final DateTime Function() _now;
  Timer? _retryTimer;
  bool loading = false;
  bool storageError = false;
  bool _disposed = false;
  int _generation = 0;
  EndpointProbeTask? _task;
  Uri? _verifiedEndpoint;
  String? _verifiedSecret;
  EndpointAssessment? _verifiedAssessment;
  int _catalogRevision = 0;
  final Map<String, EndpointCredential> _credentials = {};
  final Set<String> _credentialErrors = {};
  bool credentialUnreadable(EndpointProfile profile) =>
      _credentialErrors.contains(profile.id);
  EndpointCredential? credentialFor(EndpointProfile profile) =>
      _credentials[profile.id];
  bool _adding = false;
  String? _checkingProfileId;
  EndpointProfile? _pendingCreation;
  String? _pendingCreationSecret;

  static String _id() {
    final random = Random.secure();
    return 'profile_${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_disposed || loading) return;
    loading = true;
    final revision = ++_catalogRevision;
    storageError = false;
    _notify();
    try {
      final loaded = await repository.load();
      if (_disposed || revision != _catalogRevision) return;
      _profiles = loaded;
      _credentials.clear();
      _credentialErrors.clear();
      _notify();
      final credentials = <String, EndpointCredential>{};
      final errors = <String>{};
      for (final profile in loaded) {
        try {
          final credential = await repository.readCredential(profile);
          if (credential != null) credentials[profile.id] = credential;
        } on Object {
          errors.add(profile.id);
        }
        if (_disposed || revision != _catalogRevision) return;
      }
      if (!_disposed && revision == _catalogRevision) {
        _profiles = loaded;
        _credentials
          ..clear()
          ..addAll(credentials);
        _credentialErrors
          ..clear()
          ..addAll(errors);
      }
    } on Object {
      if (!_disposed) storageError = true;
    } finally {
      loading = false;
      _notify();
    }
  }

  void cancelProbe() => _cancelProbe(clearChecking: true);

  void _cancelProbe({required bool clearChecking}) {
    _generation++;
    _task?.cancel();
    _task = null;
    _verifiedEndpoint = null;
    _verifiedSecret = null;
    _verifiedAssessment = null;
    if (clearChecking && _checkingProfileId != null) {
      _checkingProfileId = null;
      _notify();
    }
  }

  Future<EndpointAssessment?> probe(Uri endpoint, String secret) =>
      _probe(endpoint, secret, verifyForSave: true);

  Future<EndpointAssessment?> _probe(
    Uri endpoint,
    String secret, {
    required bool verifyForSave,
  }) async {
    _cancelProbe(clearChecking: verifyForSave);
    final generation = _generation;
    if (_disposed) return null;
    try {
      final validated = EndpointProfile.validateEndpoint(endpoint);
      if (secret.isEmpty) {
        return const EndpointAssessment(EndpointStatus.authenticationRequired);
      }
      final task = _task = prober.start(validated, secret);
      final result = await task.result;
      if (_disposed || generation != _generation) return null;
      _task = null;
      if (verifyForSave) {
        _verifiedEndpoint = validated;
        _verifiedSecret = secret;
        _verifiedAssessment = result;
      }
      return result;
    } on Object {
      return _disposed || generation != _generation
          ? null
          : const EndpointAssessment(EndpointStatus.unreachable);
    }
  }

  Future<bool> add(
    Uri endpoint,
    String label,
    String secret,
    EndpointAssessment assessment,
  ) => addCredential(
    endpoint,
    label,
    EndpointCredential(kind: EndpointAuthKind.password, secret: secret),
    assessment,
  );

  Future<bool> addCredential(
    Uri endpoint,
    String label,
    EndpointCredential credential,
    EndpointAssessment assessment,
  ) async {
    final secret = credential.secret;
    if (_disposed || _adding || !assessment.canUse) return false;
    if (_verifiedEndpoint != EndpointProfile.validateEndpoint(endpoint) ||
        _verifiedSecret != secret ||
        !identical(_verifiedAssessment, assessment)) {
      return false;
    }
    storageError = false;
    _adding = true;
    // Never authorize a second identity from an uncertain first commit. The
    // next verification must reconcile this attempt through a read-only load.
    cancelProbe();
    final revision = ++_catalogRevision;
    try {
      final pending = _pendingCreation;
      if (pending != null) {
        final loaded = await repository.load();
        final matches = loaded.where((p) => p.id == pending.id);
        if (matches.isNotEmpty) {
          if (matches.single.endpoint != pending.endpoint) {
            throw const FormatException(
              'Uncertain profile identity; preserved.',
            );
          }
          final storedSecret = await repository.readSecret(matches.single);
          if (storedSecret != _pendingCreationSecret) {
            throw const FormatException(
              'Uncertain profile credential; preserved.',
            );
          }
          _pendingCreation = null;
          _pendingCreationSecret = null;
          if (pending.endpoint == EndpointProfile.validateEndpoint(endpoint) &&
              storedSecret == secret) {
            if (!_disposed && revision == _catalogRevision) {
              _profiles = loaded;
              _assessments[pending.id] = assessment;
            }
            _notify();
            return true;
          }
        } else {
          _pendingCreation = null;
          _pendingCreationSecret = null;
        }
      }
      final profile = EndpointProfile(
        id: _createId(),
        label: label.trim().isEmpty ? endpoint.host : label.trim(),
        endpoint: endpoint,
      );
      _pendingCreation = profile;
      _pendingCreationSecret = secret;
      if (credential.kind == EndpointAuthKind.password) {
        await repository.save(profile, secret);
      } else {
        await repository.saveCredential(profile, credential);
      }
      _pendingCreation = null;
      _pendingCreationSecret = null;
      // A committed save must not become a second create when refresh fails.
      // The storage-error card offers a read-only catalog retry instead.
      try {
        final loaded = await repository.load();
        if (!_disposed && revision == _catalogRevision) {
          _profiles = loaded;
          _assessments[profile.id] = assessment;
          _credentials[profile.id] = credential;
        }
      } on Object {
        if (!_disposed && revision == _catalogRevision) storageError = true;
      }
      _notify();
      return true;
    } on Object {
      storageError = true;
      _notify();
      return false;
    } finally {
      _adding = false;
    }
  }

  Future<bool> repair(
    EndpointProfile profile,
    EndpointCredential credential, {
    bool Function()? isCurrent,
  }) async {
    if (_disposed || _adding) return false;
    _adding = true;
    final revision = ++_catalogRevision;
    try {
      final previous = await repository.readCredential(profile);
      if (isCurrent?.call() == false) return false;
      final assessment = await probe(profile.endpoint, credential.secret);
      if (assessment?.canUse != true ||
          _disposed ||
          revision != _catalogRevision ||
          isCurrent?.call() == false) {
        return false;
      }
      cancelProbe();
      await repository.replaceCredential(
        profile,
        credential,
        expected: previous,
      );
      if (!_disposed && revision == _catalogRevision) {
        _credentials[profile.id] = credential;
        _credentialErrors.remove(profile.id);
        _assessments[profile.id] = assessment!;
        storageError = false;
        _notify();
      }
      return true;
    } on Object {
      storageError = true;
      _notify();
      return false;
    } finally {
      _adding = false;
    }
  }

  Future<void> check(EndpointProfile profile) async {
    if (_disposed || !canCheck(profile)) return;
    cancelProbe();
    var revision = _generation;
    _checkingProfileId = profile.id;
    _notify();
    try {
      final secret = await repository.readSecret(profile);
      if (_disposed || revision != _generation) return;
      final pending = secret == null
          ? Future.value(
              const EndpointAssessment(EndpointStatus.authenticationRequired),
            )
          : _probe(profile.endpoint, secret, verifyForSave: false);
      revision = _generation;
      final result = await pending;
      if (result != null &&
          !_disposed &&
          revision == _generation &&
          _profiles.any((p) => p.id == profile.id)) {
        _assessments[profile.id] = result;
        _armRetryTimer();
      }
    } on Object {
      if (!_disposed && revision == _generation) storageError = true;
    } finally {
      if (revision == _generation && _checkingProfileId == profile.id) {
        _checkingProfileId = null;
        _notify();
      }
    }
  }

  bool canCheck(EndpointProfile profile) {
    final assessment = _assessments[profile.id];
    return !isChecking(profile) &&
        assessment?.retryDeferred != true &&
        !(assessment?.retryAt?.isAfter(_now().toUtc()) ?? false);
  }

  bool isChecking(EndpointProfile profile) => _checkingProfileId == profile.id;

  void _armRetryTimer() {
    _retryTimer?.cancel();
    if (_disposed) return;
    DateTime? earliest;
    final now = _now().toUtc();
    for (final assessment in _assessments.values) {
      final at = assessment.retryAt;
      if (at != null &&
          at.isAfter(now) &&
          (earliest == null || at.isBefore(earliest))) {
        earliest = at;
      }
    }
    if (earliest != null) {
      _retryTimer = Timer(earliest.difference(now), () {
        _notify();
        _armRetryTimer();
      });
    }
  }

  Future<void> remove(EndpointProfile profile) async {
    cancelProbe();
    final revision = ++_catalogRevision;
    try {
      await repository.remove(profile);
      final loaded = await repository.load();
      if (_disposed) return;
      if (revision == _catalogRevision) {
        _profiles = loaded;
        _assessments.remove(profile.id);
        _credentials.remove(profile.id);
        _armRetryTimer();
      }
      storageError = false;
    } on Object {
      storageError = true;
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    cancelProbe();
    super.dispose();
  }
}
