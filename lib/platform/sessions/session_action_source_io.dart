import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:harness_opencode/harness_opencode.dart';

import '../../shared/sessions/command_ids.dart';
import '../../shared/sessions/session_actions.dart';
import 'hidden_session_store.dart';

SessionActionSource createSessionActionSource(
  EndpointProfile profile,
  EndpointCredential credential,
  EndpointProber prober, {
  HiddenSessionStore? hidden,
}) => _NativeSource(profile, credential, prober, hidden);

/// The session actions of one connected OpenCode endpoint.
///
/// The authorization is the endpoint's own contract: the version was probed
/// and observed, the profile's credential authenticates the request and the
/// row belongs to the current authoritative read. The ownership of a session
/// is evidence, not permission, and the OpenCode endpoint reports it as
/// unknown, so it is never consulted here.
final class _NativeSource implements SessionActionSource {
  _NativeSource(
    EndpointProfile profile,
    EndpointCredential credential,
    this._prober,
    this._hidden,
  ) : harness = HarnessRef(HostId(profile.id), HarnessInstanceId(profile.id)) {
    _endpoint = profile.endpoint;
    _secret = credential.secret;
    _transport = IoEndpointHttpTransport(
      endpoint: profile.endpoint,
      headers: basicEndpointHeaders(
        endpoint: profile.endpoint,
        username: 'opencode',
        secret: () => credential.secret,
      ),
    );
    _reader = OpenCodeSessionReader(_transport, harness: harness);
  }

  @override
  final HarnessRef harness;
  late final Uri _endpoint;
  late final String _secret;
  late final IoEndpointHttpTransport _transport;
  late final OpenCodeSessionReader _reader;
  final HiddenSessionStore? _hidden;

  /// The profile's own prober: the version is observed, never assumed.
  final EndpointProber _prober;
  SessionActionSupport? _support;
  Future<SessionActionSupport>? _probing;
  EndpointProbeTask? _probeTask;

  /// Whether the last probe settled on a definitive answer. A transient
  /// state is probed again instead of disabling the actions for good.
  bool _definitive = false;
  String? _version;
  bool _closed = false;

  @override
  Future<SessionActionSupport> support() async {
    final known = _support;
    if (known != null && _definitive) return known;
    final pending = _probing;
    if (pending != null) return pending;
    final future = _probeSupport();
    _probing = future;
    try {
      final support = await future;
      if (_definitive) _support = support;
      return support;
    } finally {
      _probing = null;
    }
  }

  /// The endpoint's own contract decides: the commands of the version the
  /// profile's probe observed, and nothing else.
  ///
  /// The probe is read-only and it is the profile's own, so a capability is
  /// never discovered by trying a mutation.
  Future<SessionActionSupport> _probeSupport() async {
    final task = _prober.start(_endpoint, _secret);
    _probeTask = task;
    try {
      final assessment = await task.result;
      if (assessment.status == EndpointStatus.authenticationRequired) {
        _definitive = true;
        return const SessionActionSupport(
          SessionActionReason.authenticationRequired,
        );
      }
      final version = assessment.version;
      if (version == null || !assessment.canUse) {
        // A transient state: the next request observes the endpoint again.
        _definitive = false;
        return const SessionActionSupport(
          SessionActionReason.versionUnverified,
        );
      }
      _definitive = true;
      if (OpenCodeCompatibility.parse(version)?.toString() != '2.0.22') {
        // A known version that does not define these commands.
        return const SessionActionSupport(
          SessionActionReason.versionUnverified,
        );
      }
      _version = version;
      return const SessionActionSupport(SessionActionReason.none);
    } finally {
      _probeTask = null;
    }
  }

  /// The client, once the endpoint's version was verified.
  OpenCodeSessionLifecycleClient? _client() {
    final version = _version;
    if (version == null) return null;
    return OpenCodeSessionLifecycleClient(
      _transport,
      harness: harness,
      connectedVersion: version,
    );
  }

  SessionActionOutcome _outcome(CommandReceipt receipt) =>
      switch (receipt.state.known) {
        ReceiptState.accepted => SessionActionOutcome.accepted,
        ReceiptState.rejected => SessionActionOutcome.rejected,
        ReceiptState.uncertain => SessionActionOutcome.uncertain,
        _ => SessionActionOutcome.unavailable,
      };

  @override
  SessionViewState viewState(SessionSummary row) {
    final marker = row.view;
    if (marker == null) return SessionViewState.unknown;
    return marker.unread ? SessionViewState.unread : SessionViewState.read;
  }

  @override
  Future<int?> childCount(SessionSummary row) async {
    try {
      final children = await _reader.listChildSessions(row.info.ref);
      return children.length;
    } on Object {
      return null;
    }
  }

  @override
  Future<SessionActionOutcome> rename(SessionSummary row, String title) async {
    final client = _client();
    if (client == null) return SessionActionOutcome.unavailable;
    final attempt = await client.rename(
      session: row.info.ref,
      id: mintCommandId(),
      title: title,
    );
    return _outcome(attempt.receipt);
  }

  @override
  Future<SessionActionOutcome> delete(SessionSummary row) async {
    final client = _client();
    if (client == null) return SessionActionOutcome.unavailable;
    final attempt = await client.delete(
      session: row.info.ref,
      id: mintCommandId(),
    );
    return _outcome(attempt.receipt);
  }

  @override
  Future<SessionActionOutcome> fork(SessionSummary row) async {
    final client = _client();
    if (client == null) return SessionActionOutcome.unavailable;
    // The row has no timeline position, so the whole history is copied.
    final attempt = await client.fork(session: row.info.ref, id: mintCommandId());
    return _outcome(attempt.receipt);
  }

  @override
  Future<SessionActionOutcome> markViewed(SessionSummary row) async {
    final marker = row.view;
    final idle = marker?.idleAt;
    if (idle == null) return SessionActionOutcome.unavailable;
    final client = _client();
    if (client == null) return SessionActionOutcome.unavailable;
    final attempt = await client.markViewed(
      session: row.info.ref,
      id: mintCommandId(),
      idle: idle.millisecondsSinceEpoch,
    );
    return _outcome(attempt.receipt);
  }

  @override
  bool get hideAvailable => _hidden?.loaded == true && !(_hidden?.unreadable ?? true);

  @override
  bool get hideUnreadable => _hidden?.unreadable ?? false;

  @override
  bool isHidden(SessionSummary row) =>
      _hidden?.isHidden(row.info.ref.storageKey) ?? false;

  @override
  Future<bool> setHidden(
    SessionSummary row, {
    required bool hidden,
  }) async {
    final store = _hidden;
    if (store == null) return false;
    return store.setHidden(row.info.ref.storageKey, hidden: hidden);
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _probeTask?.cancel();
    _probeTask = null;
    _reader.dispose();
    _transport.close();
  }
}
