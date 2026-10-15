import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:harness_opencode/harness_opencode.dart';
import '../../shared/sessions/session_live_source.dart';

SessionLiveDirectory? createSessionLiveDirectory({DateTime Function()? now}) =>
    _NativeLiveDirectory(now ?? DateTime.now);

/// One event stream per endpoint profile, shared by every open handle; the
/// last handle of a session unwatches it and the last of a profile closes the
/// stream. Nothing here mutates the server.
final class _NativeLiveDirectory implements SessionLiveDirectory {
  _NativeLiveDirectory(this._now);
  final DateTime Function() _now;
  final _slots = <String, _ProfileSlot>{};
  // Includes terminal slots detached from [_slots] while screens still hold
  // them, so closing the directory reaches every open stream.
  final _owned = <_ProfileSlot>{};
  bool _closed = false;

  @override
  Future<SessionLiveHandle> open({
    required EndpointProfile profile,
    required EndpointCredential credential,
    required SessionRef session,
  }) async {
    if (_closed) throw const SessionLiveException(SessionLiveFailure.cancelled);
    if (session.harnessRef !=
        HarnessRef(HostId(profile.id), HarnessInstanceId(profile.id))) {
      throw const SessionLiveException(SessionLiveFailure.incompatibleResponse);
    }
    final key = '${profile.id}|${profile.endpoint}';
    var slot = _slots[key];
    if (slot != null && !slot.credential.matches(credential)) {
      // Never multiplex two secrets over one stream.
      if (slot.handles.isNotEmpty) {
        throw const SessionLiveException(
          SessionLiveFailure.authenticationRequired,
        );
      }
      _slots.remove(key);
      unawaited(slot.close());
      slot = null;
    }
    final current = slot ?? _createSlot(key, profile, credential, session);
    try {
      await current.ready();
      return current.lease(session);
    } on Object {
      if (current.handles.isEmpty && identical(_slots[key], current)) {
        _slots.remove(key);
        unawaited(current.close());
      }
      rethrow;
    }
  }

  _ProfileSlot _createSlot(
    String key,
    EndpointProfile profile,
    EndpointCredential credential,
    SessionRef session,
  ) {
    late final _ProfileSlot slot;
    slot = _ProfileSlot(profile, credential, session.harnessRef, _now, () {
      if (identical(_slots[key], slot)) _slots.remove(key);
    });
    _owned
      ..removeWhere((owned) => owned.isClosed)
      ..add(slot);
    return _slots[key] = slot;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final slots = _owned.toList();
    _slots.clear();
    _owned.clear();
    await Future.wait([for (final slot in slots) slot.close()]);
  }
}

final class _ProfileSlot {
  _ProfileSlot(
    EndpointProfile profile,
    this.credential,
    this.harness,
    this._now,
    this._release,
  ) : _transport = IoEndpointHttpTransport(
        endpoint: profile.endpoint,
        headers: basicEndpointHeaders(
          endpoint: profile.endpoint,
          username: 'opencode',
          secret: () => credential.secret,
        ),
      ) {
    _reader = OpenCodeSessionReader(
      _transport,
      harness: harness,
      maxHistoryItems: 500,
    );
  }

  final EndpointCredential credential;
  final HarnessRef harness;
  final DateTime Function() _now;
  final void Function() _release;
  final IoEndpointHttpTransport _transport;
  late final OpenCodeSessionReader _reader;
  final _store = SessionStore(maxSessions: 8);
  IoSseRecovery? _connection;
  OpenCodeStreamOwner? _owner;
  StreamSubscription<OpenCodeStreamUpdate>? _subscription;
  Future<void>? _ready;
  Future<void>? _closing;
  String? version;
  SessionLivePhase _phase = SessionLivePhase.probing;
  final handles = <_LiveHandle>{};
  final _views = <SessionRef, SessionLiveView>{};

  Future<void> ready() => _ready ??= _probe();

  Future<void> _probe() async {
    final assessment = await OpenCodeEndpointProbe(_transport).detect();
    if (_closing != null) {
      throw const SessionLiveException(SessionLiveFailure.cancelled);
    }
    switch (assessment.status) {
      case EndpointStatus.authenticationRequired:
        throw const SessionLiveException(
          SessionLiveFailure.authenticationRequired,
        );
      case EndpointStatus.unreachable:
        throw const SessionLiveException(SessionLiveFailure.timeout);
      case EndpointStatus.cancelled:
        throw const SessionLiveException(SessionLiveFailure.cancelled);
      default:
        break;
    }
    final observed = assessment.version;
    if (!assessment.canUse || observed == null) {
      throw const SessionLiveException(SessionLiveFailure.unavailable);
    }
    // The stream reader is verified against 2.0.22 only; fail closed before
    // opening the stream instead of hydrating an unverified version.
    if (OpenCodeCompatibility.parse(observed)?.toString() != '2.0.22') {
      throw const SessionLiveException(SessionLiveFailure.incompatibleResponse);
    }
    version = observed;
    final connection = IoSseRecovery(
      _transport,
      'api/event',
      connectedWhen: openCodeServerConnected,
    );
    final owner = OpenCodeStreamOwner(
      connection: connection,
      reader: _reader,
      store: _store,
      harness: harness,
      sourceVersion: observed,
    );
    _connection = connection;
    _owner = owner;
    _phase = SessionLivePhase.connecting;
    _subscription = owner.updates.listen(_onUpdate);
    owner.start();
  }

  _LiveHandle lease(SessionRef session) {
    final owner = _owner;
    if (owner == null || _closing != null) {
      throw const SessionLiveException(SessionLiveFailure.cancelled);
    }
    final previous = _views[session];
    // A retry re-hydrates a session set aside; its other screens follow.
    if (previous?.phase == SessionLivePhase.degraded) owner.unwatch(session);
    if (!owner.watch(session)) {
      throw const SessionLiveException(SessionLiveFailure.capacity);
    }
    if (previous == null || previous.phase == SessionLivePhase.degraded) {
      final state = _store.peek(session);
      _publish(
        session,
        SessionLiveView(
          session: session,
          // A session added to a live stream hydrates on its own first.
          phase: _phase == SessionLivePhase.live && !_isLive(state)
              ? SessionLivePhase.hydrating
              : _phase,
          version: version,
          lastSyncedAt: previous?.lastSyncedAt,
          stale: previous?.lastSyncedAt != null,
          // Other screens keep the last content while it re-hydrates.
          state: previous?.state ?? state,
        ),
      );
    }
    final handle = _LiveHandle(this, session);
    handles.add(handle);
    return handle;
  }

  static bool _isLive(SessionState? state) =>
      state?.connection.kind.known == ConnectionKind.live;

  SessionLiveView view(SessionRef session) =>
      _views[session] ??
      SessionLiveView(session: session, phase: SessionLivePhase.closed);

  void _publish(SessionRef session, SessionLiveView view) {
    _views[session] = view;
    for (final handle in handles.toList()) {
      if (handle.session == session) handle.emit(view);
    }
  }

  void _onUpdate(OpenCodeStreamUpdate update) {
    switch (update) {
      case OpenCodeSessionUpdated(:final ref, :final state):
        final previous = _views[ref];
        if (previous == null) return;
        // A disconnect snapshot arrives before the reconnecting update.
        final live = _phase == SessionLivePhase.live && _isLive(state);
        _publish(
          ref,
          SessionLiveView(
            session: ref,
            phase: previous.phase == SessionLivePhase.degraded
                ? SessionLivePhase.degraded
                : _phase == SessionLivePhase.live && !live
                ? SessionLivePhase.hydrating
                : _phase,
            failure: previous.failure,
            version: version,
            lastSyncedAt: live ? _now() : previous.lastSyncedAt,
            // Stale means it was current once; a first hydration is not.
            stale: !live && previous.lastSyncedAt != null,
            state: state,
          ),
        );
      case OpenCodeSessionEvicted(:final ref):
        if (!_views.containsKey(ref)) return;
        _publish(
          ref,
          SessionLiveView(
            session: ref,
            phase: SessionLivePhase.evicted,
            failure: SessionLiveFailure.notFound,
            version: version,
          ),
        );
      case OpenCodeConnectionUpdated(:final kind, :final session):
        final phase = switch (kind) {
          ConnectionKind.hydrating => SessionLivePhase.hydrating,
          ConnectionKind.live => SessionLivePhase.live,
          ConnectionKind.reconnecting => SessionLivePhase.reconnecting,
          ConnectionKind.degraded => SessionLivePhase.degraded,
          ConnectionKind.authRequired => SessionLivePhase.authRequired,
          ConnectionKind.incompatible => SessionLivePhase.incompatible,
          _ => SessionLivePhase.connecting,
        };
        final failure = switch (phase) {
          SessionLivePhase.degraded => SessionLiveFailure.unavailable,
          SessionLivePhase.authRequired =>
            SessionLiveFailure.authenticationRequired,
          SessionLivePhase.incompatible =>
            SessionLiveFailure.incompatibleResponse,
          _ => null,
        };
        if (session == null) {
          _phase = phase;
          // A terminal stream never recovers; new leases get a fresh slot
          // while open screens keep showing this one until they retry.
          if (phase == SessionLivePhase.authRequired ||
              phase == SessionLivePhase.incompatible) {
            _release();
          }
        }
        for (final MapEntry(key: ref, value: previous)
            in _views.entries.toList()) {
          if (session != null && session != ref) continue;
          // A session set aside stays aside until a new generation hydrates.
          final keep =
              session == null &&
              previous.phase == SessionLivePhase.degraded &&
              phase == SessionLivePhase.live;
          if (previous.phase == SessionLivePhase.evicted) continue;
          final live = phase == SessionLivePhase.live && !keep;
          _publish(
            ref,
            SessionLiveView(
              session: ref,
              phase: keep ? SessionLivePhase.degraded : phase,
              failure: keep ? previous.failure : failure,
              version: version,
              lastSyncedAt: live && previous.state != null
                  ? _now()
                  : previous.lastSyncedAt,
              stale: !live && previous.lastSyncedAt != null,
              state: previous.state,
            ),
          );
        }
    }
  }

  void release(_LiveHandle handle) {
    if (!handles.remove(handle)) return;
    if (!handles.any((h) => h.session == handle.session)) {
      _owner?.unwatch(handle.session);
      _views.remove(handle.session);
    }
    if (handles.isEmpty) {
      _release();
      unawaited(close());
    }
  }

  bool get isClosed => _closing != null;

  Future<void> close() => _closing ??= _shutdown();

  Future<void> _shutdown() async {
    for (final handle in handles.toList()) {
      handle.detach();
    }
    handles.clear();
    await _subscription?.cancel();
    await _owner?.close();
    await _connection?.close();
    _reader.dispose();
    _transport.close();
    _store.clear();
  }
}

final class _LiveHandle implements SessionLiveHandle {
  _LiveHandle(this._slot, this.session);
  final _ProfileSlot _slot;
  @override
  final SessionRef session;
  final _controller = StreamController<SessionLiveView>.broadcast();
  bool _closed = false;

  @override
  SessionLiveView get current => _closed
      ? SessionLiveView(session: session, phase: SessionLivePhase.closed)
      : _slot.view(session);

  @override
  Stream<SessionLiveView> get updates => Stream.multi((listener) {
    listener.add(current);
    final subscription = _controller.stream.listen(
      listener.add,
      onDone: listener.close,
    );
    listener.onCancel = subscription.cancel;
  });

  void emit(SessionLiveView view) {
    if (!_closed) _controller.add(view);
  }

  void detach() {
    if (_closed) return;
    _controller.add(
      SessionLiveView(session: session, phase: SessionLivePhase.closed),
    );
    _closed = true;
    unawaited(_controller.close());
  }

  @override
  void close() {
    if (_closed) return;
    _slot.release(this);
    detach();
  }
}
