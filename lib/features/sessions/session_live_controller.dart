import 'dart:async';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';
import '../../shared/sessions/session_live_source.dart';
import '../hosts/hosts_controller.dart';

/// Owns one screen's live, read-only lease; it never starts, stops or answers
/// anything on the server.
class SessionLiveController extends ChangeNotifier {
  SessionLiveController({
    required this.hosts,
    required this.profile,
    required this.summary,
    required this.directory,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    hosts.addListener(_hostsChanged);
  }
  final HostsController hosts;
  final EndpointProfile profile;
  final SessionSummary summary;
  final SessionLiveDirectory directory;
  final DateTime Function() _now;
  SessionRef get session => summary.info.ref;
  EndpointCredential? _credential;
  SessionLiveHandle? _handle;
  StreamSubscription<SessionLiveView>? _subscription;
  Timer? _expiry;
  bool _disposed = false;
  int _generation = 0;

  SessionLiveView? view;
  SessionLiveFailure? failure;
  bool opening = false;

  SessionState? get state => view?.state;
  SessionLivePhase get phase => view?.phase ?? SessionLivePhase.probing;
  bool get loading =>
      opening ||
      const {
        SessionLivePhase.probing,
        SessionLivePhase.connecting,
        SessionLivePhase.hydrating,
      }.contains(view?.phase);

  /// A terminal state the transport will not recover from on its own.
  bool get canRetry =>
      !opening &&
      (failure != null ||
          const {
            SessionLivePhase.degraded,
            SessionLivePhase.authRequired,
            SessionLivePhase.incompatible,
            SessionLivePhase.evicted,
            SessionLivePhase.closed,
          }.contains(view?.phase));

  EndpointCredential? _currentCredential() {
    if (_disposed || hosts.loading || hosts.storageError) return null;
    for (final current in hosts.profiles) {
      if (current.id == profile.id &&
          current.endpoint == profile.endpoint &&
          !hosts.credentialUnreadable(current)) {
        final credential = hosts.credentialFor(current);
        if (credential != null &&
            (credential.expiresAt == null ||
                _now().toUtc().isBefore(credential.expiresAt!))) {
          return credential;
        }
      }
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _detach() {
    _generation++;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _handle?.close();
    _handle = null;
    _expiry?.cancel();
    _expiry = null;
    opening = false;
  }

  SessionLiveFailure _missingCredential() => hosts.loading || hosts.storageError
      ? SessionLiveFailure.unavailable
      : SessionLiveFailure.authenticationRequired;

  void _hostsChanged() {
    if (_disposed) return;
    final credential = _currentCredential();
    if (credential == null || _credential?.matches(credential) != true) {
      _detach();
      view = null;
      failure = _missingCredential();
      _notify();
    }
  }

  Future<void> start() async {
    if (_disposed) return;
    _detach();
    final credential = _currentCredential();
    if (credential == null) {
      view = null;
      failure = _missingCredential();
      _notify();
      return;
    }
    _credential = credential;
    failure = null;
    opening = true;
    final generation = _generation;
    _notify();
    try {
      final handle = await directory.open(
        profile: profile,
        credential: credential,
        session: session,
      );
      if (_disposed || generation != _generation) {
        handle.close();
        return;
      }
      if (handle.session != session) {
        handle.close();
        throw const SessionLiveException(
          SessionLiveFailure.incompatibleResponse,
        );
      }
      _handle = handle;
      if (credential.expiresAt case final deadline?) {
        _expiry = Timer(deadline.difference(_now().toUtc()), _hostsChanged);
      }
      _subscription = handle.updates.listen((next) {
        if (_disposed || generation != _generation) return;
        view = next;
        if (next.phase == SessionLivePhase.evicted) failure = next.failure;
        _notify();
      });
    } on Object catch (error) {
      if (_disposed || generation != _generation) return;
      failure = error is SessionLiveException
          ? error.failure
          : SessionLiveFailure.connection;
    } finally {
      if (!_disposed && generation == _generation) {
        opening = false;
        _notify();
      }
    }
  }

  /// Opens a fresh lease after a terminal state; reconnecting is the
  /// transport's job, so a live or reconnecting view is left alone.
  Future<void> retry() async {
    if (!canRetry) return;
    view = null;
    await start();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    hosts.removeListener(_hostsChanged);
    _detach();
    super.dispose();
  }
}
