import '../events.dart';
import '../identity.dart';
import '../session.dart';
import 'effects.dart';
import 'session_reducer.dart';

/// In-memory LRU of open sessions, keyed by the complete canonical SessionRef.
/// Eviction only forgets local observations; it never stops remote execution.
final class SessionStore {
  SessionStore({
    required this.maxSessions,
    this.limits = const ReducerLimits(),
  }) {
    if (maxSessions <= 0) {
      throw ArgumentError('Session LRU capacity must be positive');
    }
    // Validate the limits without requiring an invented session identity.
    if (limits.maxItems <= 0 ||
        limits.maxItems > 500 ||
        limits.maxSeen <= 0 ||
        limits.maxDiagnostics <= 0 ||
        limits.maxObservations <= 0) {
      throw ArgumentError('Invalid reducer limits');
    }
  }

  final int maxSessions;
  final ReducerLimits limits;
  final _sessions = <SessionRef, SessionState>{};

  int get length => _sessions.length;
  List<SessionRef> get refs => List.unmodifiable(_sessions.keys);

  SessionState? peek(SessionRef ref) => _sessions[ref];

  SessionState open(SessionRef ref) {
    final state = _sessions.remove(ref) ?? SessionState(ref, limits: limits);
    _sessions[ref] = state;
    _evict();
    return state;
  }

  SessionState? read(SessionRef ref) {
    final state = _sessions.remove(ref);
    if (state != null) _sessions[ref] = state;
    return state;
  }

  Reduction apply(SessionRef ref, SessionEvent event) {
    final state = _sessions[ref];
    if (state == null) {
      return Reduction(SessionState(ref, limits: limits), [
        Rehydrate(ref, 'sessionNotOpen'),
      ]);
    }
    final result = reduce(state, event);
    _remember(result.state);
    return result;
  }

  Reduction applySnapshot(SessionRef ref, SessionSnapshot snapshot) {
    final state = _sessions[ref];
    if (state == null) {
      return Reduction(SessionState(ref, limits: limits), [
        Rehydrate(ref, 'sessionNotOpen'),
      ]);
    }
    final result = hydrate(state, snapshot);
    _remember(result.state);
    return result;
  }

  SessionState startHydration(
    SessionRef ref, {
    required String generation,
    required StreamPosition readStart,
  }) {
    final state = _sessions[ref];
    if (state == null) throw StateError('Open session before hydration');
    final next = beginHydration(
      state,
      generation: generation,
      readStart: readStart,
    );
    _remember(next);
    return next;
  }

  SessionState? disconnected(SessionRef ref) {
    final state = _sessions[ref];
    if (state == null) return null;
    final next = disconnect(state);
    _remember(next);
    return next;
  }

  void close(SessionRef ref) => _sessions.remove(ref);
  void clear() => _sessions.clear();

  void _remember(SessionState state) {
    _sessions.remove(state.ref);
    _sessions[state.ref] = state;
    _evict();
  }

  void _evict() {
    while (_sessions.length > maxSessions) {
      _sessions.remove(_sessions.keys.first);
    }
  }
}
