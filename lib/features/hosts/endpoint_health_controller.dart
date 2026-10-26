import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';

import 'hosts_controller.dart';

enum EndpointHealthStatus { online, delayed, offline }

enum EndpointCredentialFailure { missing, unreadable, expired }

/// Endpoint reachability stays separate from a conversation's stream state.
final class EndpointHealthView {
  const EndpointHealthView({
    this.assessment,
    this.credentialFailure,
    this.checking = false,
    this.checkedAt,
  });

  final EndpointAssessment? assessment;
  final EndpointCredentialFailure? credentialFailure;
  final bool checking;
  final DateTime? checkedAt;

  EndpointHealthStatus get status {
    if (credentialFailure != null) return EndpointHealthStatus.offline;
    return switch (assessment?.status) {
      EndpointStatus.compatible => EndpointHealthStatus.online,
      null ||
      EndpointStatus.untested ||
      EndpointStatus.cancelled => EndpointHealthStatus.delayed,
      _ => EndpointHealthStatus.offline,
    };
  }
}

/// Observes every saved endpoint while the app is visible. Each probe belongs
/// to this lane; it never borrows or cancels the Hosts page's manual task.
final class EndpointHealthController extends ChangeNotifier {
  EndpointHealthController({
    required this.hosts,
    DateTime Function()? now,
    this.interval = const Duration(seconds: 10),
  }) : _now = now ?? DateTime.now {
    if (interval <= Duration.zero) throw ArgumentError.value(interval);
    hosts.addListener(_sync);
  }

  final HostsController hosts;
  final Duration interval;
  final DateTime Function() _now;
  final _records = <String, _HealthRecord>{};
  Timer? _timer;
  Timer? _expiry;
  bool _started = false;
  bool _foreground = false;
  bool _disposed = false;
  DateTime? _resumedAt;

  bool get foreground => _foreground;
  DateTime? get resumedAt => _resumedAt;
  DateTime get now => _now().toUtc();
  bool get _ready =>
      hosts.loaded &&
      !hosts.loading &&
      !hosts.storageError &&
      hosts.pendingBindingChange == null;

  void start({required bool foreground}) {
    if (_disposed || _started) return;
    _started = true;
    _foreground = foreground;
    if (foreground) _resumedAt = now;
    if (!hosts.loaded && !hosts.loading) unawaited(hosts.load());
    _sync();
  }

  void setForeground(bool value) {
    if (_disposed || !_started || value == _foreground) return;
    _foreground = value;
    if (value) {
      _resumedAt = now;
      // A resume rechecks now, while retaining the server's retry fence.
      for (final record in _records.values) {
        record.nextAt = now;
      }
    }
    _sync();
  }

  EndpointHealthView view(EndpointProfile profile) {
    if (!_saved(profile)) return const EndpointHealthView();
    if (!_ready) {
      final record = _records[profile.id];
      if (record == null || !record.profile.sameBinding(profile)) {
        return const EndpointHealthView();
      }
      // Reloading temporarily empties the credential cache. It cannot prove
      // recovery from a confirmed failure or unblock the retained live view.
      final retained = EndpointHealthView(
        assessment: record.assessment,
        credentialFailure: record.credentialFailure,
        checkedAt: record.checkedAt,
      );
      return retained.status == EndpointHealthStatus.offline
          ? retained
          : const EndpointHealthView();
    }
    final credential = hosts.credentialFor(profile);
    final failure = _credentialFailure(profile, credential);
    final record = _records[profile.id];
    if (record == null || !_matches(record, profile, credential)) {
      return EndpointHealthView(credentialFailure: failure);
    }
    return EndpointHealthView(
      assessment: record.assessment,
      credentialFailure: failure,
      checking: record.task != null,
      checkedAt: record.checkedAt,
    );
  }

  bool canRefresh(EndpointProfile profile) {
    final record = _records[profile.id];
    return record != null &&
        _saved(profile) &&
        _canProbe(record, automatic: false);
  }

  Future<void> refresh(EndpointProfile profile) async {
    final record = _records[profile.id];
    if (record == null || !canRefresh(profile)) return;
    await _probe(record);
  }

  bool _saved(EndpointProfile profile) =>
      hosts.profiles.any((saved) => saved.sameBinding(profile));

  EndpointCredentialFailure? _credentialFailure(
    EndpointProfile profile,
    EndpointCredential? credential,
  ) {
    if (hosts.credentialUnreadable(profile)) {
      return EndpointCredentialFailure.unreadable;
    }
    if (credential == null) return EndpointCredentialFailure.missing;
    final expiresAt = credential.expiresAt;
    if (expiresAt != null && !expiresAt.isAfter(now)) {
      return EndpointCredentialFailure.expired;
    }
    return null;
  }

  bool _matches(
    _HealthRecord record,
    EndpointProfile profile,
    EndpointCredential? credential,
  ) =>
      record.profile.sameBinding(profile) &&
      (record.credential == null
          ? credential == null
          : record.credential!.matches(credential));

  void _sync() {
    if (_disposed || !_started) return;
    if (!_ready || !_foreground) {
      _timer?.cancel();
      _timer = null;
      _expiry?.cancel();
      _expiry = null;
      for (final record in _records.values) {
        _cancel(record);
      }
      _notify();
      return;
    }
    final ids = {for (final profile in hosts.profiles) profile.id};
    for (final id in _records.keys.toList()) {
      if (!ids.contains(id)) _cancel(_records.remove(id)!);
    }
    for (final profile in hosts.profiles) {
      final credential = hosts.credentialFor(profile);
      var record = _records[profile.id];
      if (record == null || !_matches(record, profile, credential)) {
        if (record != null) _cancel(record);
        record = _records[profile.id] = _HealthRecord(
          profile,
          credential,
          now,
          hosts.assessments[profile.id],
        );
      }
      final failure = _credentialFailure(profile, credential);
      if (failure != record.credentialFailure) {
        record.credentialFailure = failure;
        if (failure != null) _cancel(record);
      }
      final observed = hosts.assessments[profile.id];
      if (!identical(observed, record.hostAssessment)) {
        record.hostAssessment = observed;
        if (observed != null && observed.status != EndpointStatus.cancelled) {
          // A manual result is newer evidence than this lane's pending read.
          // Its revision prevents that older result from replacing it.
          record.observation++;
          record.assessment = observed;
          record.checkedAt = now;
          record.nextAt = now.add(interval);
        }
      }
      if (_canProbe(record)) unawaited(_probe(record, notify: false));
    }
    if (_records.isEmpty) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(interval, (_) => _sync());
    }
    _expiry?.cancel();
    final expiries =
        _records.values
            .map((record) => record.credential?.expiresAt)
            .whereType<DateTime>()
            .where((expiry) => expiry.isAfter(now))
            .toList()
          ..sort();
    _expiry = expiries.isEmpty
        ? null
        : Timer(expiries.first.difference(now), _sync);
    _notify();
  }

  bool _canProbe(_HealthRecord record, {bool automatic = true}) {
    if (_disposed ||
        !_started ||
        !_foreground ||
        !_ready ||
        record.task != null ||
        _credentialFailure(record.profile, record.credential) != null ||
        !(_matches(
          record,
          record.profile,
          hosts.credentialFor(record.profile),
        )) ||
        !_saved(record.profile)) {
      return false;
    }
    final assessment = record.assessment;
    return assessment?.retryDeferred != true &&
        !(assessment?.retryAt?.isAfter(now) ?? false) &&
        (!automatic || !record.nextAt.isAfter(now));
  }

  Future<void> _probe(_HealthRecord record, {bool notify = true}) async {
    final credential = record.credential;
    if (credential == null) return;
    final generation = ++record.generation;
    final observation = record.observation;
    record.nextAt = now.add(interval);
    EndpointAssessment result;
    try {
      final task = record.task = hosts.prober.start(
        record.profile.endpoint,
        credential.secret,
      );
      if (notify) _notify();
      result = await task.result;
    } on Object {
      result = const EndpointAssessment(EndpointStatus.unreachable);
    }
    if (_disposed ||
        !identical(_records[record.profile.id], record) ||
        generation != record.generation) {
      return;
    }
    record.task = null;
    if (!_foreground ||
        !_ready ||
        !_matches(
          record,
          record.profile,
          hosts.credentialFor(record.profile),
        )) {
      return;
    }
    record.credentialFailure = _credentialFailure(record.profile, credential);
    if (record.credentialFailure == null &&
        observation == record.observation &&
        result.status != EndpointStatus.cancelled) {
      record.observation++;
      record.assessment = result;
      record.hostAssessment = result;
      record.checkedAt = now;
      hosts.observeAssessment(record.profile, credential, result);
    }
    _notify();
  }

  void _cancel(_HealthRecord record) {
    record.generation++;
    record.task?.cancel();
    record.task = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    hosts.removeListener(_sync);
    _timer?.cancel();
    _expiry?.cancel();
    for (final record in _records.values) {
      _cancel(record);
    }
    _records.clear();
    super.dispose();
  }
}

final class _HealthRecord {
  _HealthRecord(this.profile, this.credential, this.nextAt, this.hostAssessment)
    : assessment = hostAssessment?.status == EndpointStatus.cancelled
          ? null
          : hostAssessment;

  final EndpointProfile profile;
  final EndpointCredential? credential;
  DateTime nextAt;
  EndpointAssessment? hostAssessment;
  EndpointAssessment? assessment;
  EndpointCredentialFailure? credentialFailure;
  EndpointProbeTask? task;
  DateTime? checkedAt;
  int generation = 0;
  int observation = 0;
}
