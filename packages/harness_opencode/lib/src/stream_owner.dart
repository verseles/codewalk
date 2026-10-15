import 'dart:async';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';

import 'event_projection.dart';
import 'session_reader.dart';

/// Readiness predicate for the event stream connection: the transport must be
/// built with `connectedWhen: openCodeServerConnected`, so it holds every
/// later frame until the owner releases the generation.
bool openCodeServerConnected(SseFrame frame) {
  try {
    final value = jsonDecode(frame.data);
    return value is Map && value['type'] == 'server.connected';
  } on FormatException {
    return false;
  }
}

/// Finite stream-owner failure categories; never native content.
enum OpenCodeStreamFailure { malformedControl, hydrationExhausted, terminal }

sealed class OpenCodeStreamUpdate {
  const OpenCodeStreamUpdate();
}

/// One reduction applied to a watched session's state.
final class OpenCodeSessionUpdated extends OpenCodeStreamUpdate {
  OpenCodeSessionUpdated(this.ref, this.state, Iterable<ReducerEffect> effects)
    : effects = List.unmodifiable(effects);
  final SessionRef ref;
  final SessionState state;
  final List<ReducerEffect> effects;
}

/// The server no longer has the session; it was closed in the store.
final class OpenCodeSessionEvicted extends OpenCodeStreamUpdate {
  const OpenCodeSessionEvicted(this.ref);
  final SessionRef ref;
}

/// Connection confidence for the whole stream, with a finite failure when one
/// stopped progress.
final class OpenCodeConnectionUpdated extends OpenCodeStreamUpdate {
  const OpenCodeConnectionUpdated(this.kind, {this.failure, this.session});
  final ConnectionKind kind;
  final OpenCodeStreamFailure? failure;

  /// Set when the failure concerns one session rather than the stream.
  final SessionRef? session;
}

final class _Watch {
  bool ready = false;
  bool stalled = false;
  bool hydrating = false;
  bool dirty = false;
  int repairs = 0;
  RequestCancellation? cancellation;
  final held = <(int, Map<String, Object?>)>[];
}

const _retryable = {
  OpenCodeSessionReadFailure.unavailable,
  OpenCodeSessionReadFailure.timeout,
  OpenCodeSessionReadFailure.connection,
  OpenCodeSessionReadFailure.rateLimited,
};

/// The single consumer of `GET /api/event` for one OpenCode 2.0.22 harness.
///
/// For each connection generation it hydrates every watched session from one
/// shared read start (`hydrateSession`), then releases the generation and
/// reduces each later frame, in arrival order, through [projectOpenCodeEvent]
/// into the [SessionStore]. Stream positions use the generation as epoch and
/// count every frame after the connection frame, so a snapshot's read
/// barriers order it against the frames around it.
///
/// A session watched after the release keeps its own frames until its first
/// snapshot, so none is projected against an empty state. Repair requests from
/// the reducer, and frames a producer rejects, coalesce into one bounded
/// re-hydration per session; a session whose hydration keeps failing is set
/// aside (disconnected, frames skipped) instead of holding the others back,
/// and a session the server reports missing is evicted. Disconnects mark every
/// watched session; reconnecting is the transport's job.
final class OpenCodeStreamOwner {
  OpenCodeStreamOwner({
    required this.connection,
    required this.reader,
    required this.store,
    required this.harness,
    required this.sourceVersion,
    DateTime Function()? now,
    Future<void> Function(Duration delay)? delay,
    this.maxHydrationAttempts = 3,
    this.maxRepairs = 3,
    this.maxHeldFrames = 256,
  }) : _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed,
       streamId = 'opencode:/api/event:${harness.storageKey}' {
    if (maxHydrationAttempts <= 0 || maxRepairs < 0 || maxHeldFrames <= 0) {
      throw ArgumentError('Stream owner limits must be positive.');
    }
  }

  final RecoveringSseConnection connection;
  final OpenCodeSessionReader reader;
  final SessionStore store;
  final HarnessRef harness;
  final String sourceVersion;
  final int maxHydrationAttempts;
  final int maxRepairs;
  final int maxHeldFrames;
  final String streamId;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;

  final _updates = StreamController<OpenCodeStreamUpdate>.broadcast();
  final _watched = <SessionRef, _Watch>{};
  StreamSubscription<SseRecoveryUpdate>? _subscription;
  int? _generation;
  bool _released = false;
  bool _woke = false;
  bool _closed = false;
  int _seq = 0;

  Stream<OpenCodeStreamUpdate> get updates => _updates.stream;
  Iterable<SessionRef> get watched => List.unmodifiable(_watched.keys);

  void start() {
    if (_closed || _subscription != null) return;
    _subscription = connection.updates.listen(_onUpdate);
  }

  /// Opens [ref] in the store and keeps it hydrated; remote work is untouched.
  /// Refused (false) when the store could not keep every watched session,
  /// since its LRU would silently evict one of them.
  bool watch(SessionRef ref) {
    if (_closed || ref.harnessRef != harness) return false;
    if (_watched.containsKey(ref)) return true;
    if (_watched.length >= store.maxSessions) return false;
    store.open(ref);
    _watched[ref] = _Watch();
    // During the gate the generation loop picks it up before release.
    if (_generation != null && _released) unawaited(_hydrate(ref));
    return true;
  }

  /// Forgets [ref] locally; it never interrupts remote execution.
  void unwatch(SessionRef ref) {
    final watch = _watched.remove(ref);
    if (watch == null) return;
    watch.cancellation?.cancel();
    store.close(ref);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final watch in _watched.values) {
      watch.cancellation?.cancel();
    }
    await _subscription?.cancel();
    await _updates.close();
  }

  StreamPosition _position(int seq) => StreamPosition(
    id: streamId,
    epoch: '$_generation',
    seq: BigInt.from(seq),
  );

  void _emit(OpenCodeStreamUpdate update) {
    if (!_closed) _updates.add(update);
  }

  void _onUpdate(SseRecoveryUpdate update) {
    if (_closed) return;
    switch (update) {
      case SseConnected(:final generation, :final firstFrame):
        unawaited(_onConnected(generation, firstFrame));
      case SseBatch(:final generation, :final frames):
        if (generation != _generation || !_released) return;
        for (final frame in frames) {
          _onFrame(frame);
        }
      case SseDisconnected(:final generation, :final failure, :final terminal):
        // An attempt that failed before connecting never had a generation
        // here; its terminal end still stops the stream.
        if (generation != _generation && !(terminal && _generation == null)) {
          return;
        }
        _onDisconnected(failure, terminal);
    }
  }

  Future<void> _onConnected(int generation, SseFrame? first) async {
    for (final watch in _watched.values) {
      watch.cancellation?.cancel();
    }
    if (first == null || !openCodeServerConnected(first)) {
      _generation = null;
      _emit(
        const OpenCodeConnectionUpdated(
          ConnectionKind.incompatible,
          failure: OpenCodeStreamFailure.malformedControl,
        ),
      );
      return;
    }
    _generation = generation;
    _released = false;
    _woke = false;
    _seq = 0;
    // Fresh per-generation bookkeeping: work left over from an older
    // generation sees a different watch and stops touching this one.
    for (final ref in _watched.keys.toList()) {
      _watched[ref] = _Watch();
    }
    _emit(const OpenCodeConnectionUpdated(ConnectionKind.hydrating));
    // Sequential, including sessions watched while the gate is open.
    while (true) {
      if (_closed || _generation != generation) return;
      final next = _watched.entries
          .where((e) => !e.value.ready && !e.value.stalled)
          .map((e) => e.key)
          .firstOrNull;
      if (next == null) break;
      await _hydrate(next);
    }
    if (_closed || _generation != generation) return;
    _released = true;
    connection.releaseGeneration(generation);
    _emit(const OpenCodeConnectionUpdated(ConnectionKind.live));
    for (final MapEntry(key: ref, value: watch) in _watched.entries.toList()) {
      if (watch.dirty) {
        watch.dirty = false;
        _repair(ref);
      }
    }
  }

  /// Hydrates one session with bounded retries; stale results are dropped.
  Future<void> _hydrate(SessionRef ref) async {
    final watch = _watched[ref];
    final generation = _generation;
    if (watch == null || generation == null || watch.hydrating) return;
    watch.hydrating = true;
    try {
      for (var attempt = 1; ; attempt++) {
        final cancellation = RequestCancellation();
        watch.cancellation = cancellation;
        final readStart = _position(_seq);
        // A shared store may have evicted it; watching keeps it open.
        if (store.peek(ref) == null) store.open(ref);
        store.startHydration(
          ref,
          generation: '$generation',
          readStart: readStart,
        );
        try {
          final snapshot = await reader.hydrateSession(
            ref,
            hydrationGeneration: '$generation',
            readStart: readStart,
            sourceVersion: sourceVersion,
            historyLimit: 200,
            now: _now,
            cancellation: cancellation,
          );
          if (!_current(ref, watch, generation) || watch.stalled) return;
          final result = store.applySnapshot(ref, snapshot);
          // Evicted by another user of a shared store during the read: the
          // snapshot was not stored, so read again into a reopened state.
          if (result.effects.any(
            (e) => e is Rehydrate && e.reason == 'sessionNotOpen',
          )) {
            if (attempt < maxHydrationAttempts) continue;
            _setAside(ref, watch);
            return;
          }
          _emit(OpenCodeSessionUpdated(ref, result.state, result.effects));
          watch
            ..ready = true
            ..stalled = false;
          final held = List.of(watch.held);
          watch.held.clear();
          for (final (seq, value) in held) {
            if (!_current(ref, watch, generation)) return;
            _apply(ref, value, seq);
          }
          _handle(ref, result.effects);
          return;
        } on OpenCodeSessionReadException catch (error) {
          if (!_current(ref, watch, generation) ||
              watch.stalled ||
              error.failure == OpenCodeSessionReadFailure.cancelled) {
            return;
          }
          if (error.failure == OpenCodeSessionReadFailure.notFound) {
            _evict(ref);
            return;
          }
          if (_retryable.contains(error.failure) &&
              attempt < maxHydrationAttempts) {
            await _delay(Duration(seconds: 1 << (attempt - 1)));
            if (!_current(ref, watch, generation) || watch.stalled) return;
            continue;
          }
          _setAside(ref, watch);
          return;
        }
      }
    } finally {
      watch.hydrating = false;
      watch.cancellation = null;
      if (watch.dirty && _released && _current(ref, watch, generation)) {
        watch.dirty = false;
        _repair(ref);
      }
    }
  }

  bool _current(SessionRef ref, _Watch watch, int generation) =>
      !_closed && _generation == generation && identical(_watched[ref], watch);

  void _setAside(SessionRef ref, _Watch watch) {
    watch.cancellation?.cancel();
    watch
      ..ready = false
      ..stalled = true
      ..held.clear();
    final state = store.disconnected(ref);
    if (state != null) _emit(OpenCodeSessionUpdated(ref, state, const []));
    _emit(
      OpenCodeConnectionUpdated(
        ConnectionKind.degraded,
        failure: OpenCodeStreamFailure.hydrationExhausted,
        session: ref,
      ),
    );
  }

  void _evict(SessionRef ref) {
    final watch = _watched.remove(ref);
    watch?.cancellation?.cancel();
    store.close(ref);
    _emit(OpenCodeSessionEvicted(ref));
  }

  /// One coalesced, bounded re-hydration on the current generation.
  void _repair(SessionRef ref) {
    final watch = _watched[ref];
    if (watch == null || watch.stalled) return;
    if (watch.hydrating || !_released) {
      watch.dirty = true;
      return;
    }
    if (watch.repairs >= maxRepairs) {
      _setAside(ref, watch);
      return;
    }
    watch.repairs++;
    unawaited(_hydrate(ref));
  }

  void _onFrame(SseFrame frame) {
    final seq = ++_seq;
    final Object? value;
    try {
      value = jsonDecode(frame.data);
    } on FormatException {
      return;
    }
    if (value is! Map<String, Object?>) return;
    final data = value['data'];
    Object? session;
    if (data is Map<String, Object?>) {
      final form = data['form'];
      session =
          data['sessionID'] ??
          (form is Map<String, Object?> ? form['sessionID'] : null);
    }
    if (session is! String || session.isEmpty) return;
    final ref = SessionRef(harness.host, harness.harness, session);
    final watch = _watched[ref];
    if (watch == null || watch.stalled) return;
    if (!watch.ready) {
      if (watch.held.length >= maxHeldFrames) {
        _setAside(ref, watch);
        return;
      }
      watch.held.add((seq, value));
      return;
    }
    _apply(ref, value, seq);
  }

  void _apply(SessionRef ref, Map<String, Object?> value, int seq) {
    final state = store.read(ref);
    if (state == null) {
      // Lost from a shared store: never drop frames silently, re-read.
      _watched[ref]?.ready = false;
      _repair(ref);
      return;
    }
    final List<SessionEvent> events;
    try {
      events = projectOpenCodeEvent(
        value,
        state,
        sourceVersion: sourceVersion,
        position: _position(seq),
        receivedAt: _now(),
      );
    } on Exception {
      // A rejected frame is not guessed around: the session is re-read.
      _repair(ref);
      return;
    }
    for (final event in events) {
      final result = store.apply(ref, event);
      _emit(OpenCodeSessionUpdated(ref, result.state, result.effects));
      _handle(ref, result.effects);
    }
  }

  /// At most one repair per reduction, however many effects ask for it.
  void _handle(SessionRef ref, List<ReducerEffect> effects) {
    var repair = false;
    for (final effect in effects) {
      switch (effect) {
        case Rehydrate(:final reason):
          if (reason == 'sessionNotOpen') continue;
          if (reason == 'streamGenerationMismatch' ||
              reason == 'snapshotGenerationMismatch') {
            if (!_woke) {
              _woke = true;
              connection.wake();
            }
            continue;
          }
          repair = true;
        case Refetch():
          repair = true;
        case Notify():
          break;
      }
    }
    if (repair) _repair(ref);
  }

  void _onDisconnected(TransportException failure, bool terminal) {
    for (final MapEntry(key: ref, value: watch) in _watched.entries) {
      watch
        ..cancellation?.cancel()
        ..ready = false
        ..held.clear();
      final state = store.disconnected(ref);
      if (state != null) _emit(OpenCodeSessionUpdated(ref, state, const []));
    }
    // Hydration and release of this generation are abandoned with it.
    _generation = null;
    _released = false;
    if (!terminal) {
      _emit(const OpenCodeConnectionUpdated(ConnectionKind.reconnecting));
      return;
    }
    final status = failure.statusCode;
    _emit(
      OpenCodeConnectionUpdated(
        status == 401 || status == 403
            ? ConnectionKind.authRequired
            : ConnectionKind.incompatible,
        failure: OpenCodeStreamFailure.terminal,
      ),
    );
  }
}
