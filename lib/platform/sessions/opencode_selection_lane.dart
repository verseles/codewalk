import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:harness_opencode/harness_opencode.dart';
import '../../shared/sessions/session_live_source.dart';
import '../../shared/sessions/session_selection.dart';

/// The model and agent of the sessions one OpenCode profile watches.
///
/// Each session reads its location's catalog once per live period and keeps
/// one switch in flight at most. A switch is never sent again on its own: an
/// uncertain one is settled by one read of the session's record, then by a
/// newer server selection, an explicit refresh or a new pick. It lives in its
/// own file so the profile slot stays below the architecture guard's
/// file-size limit.
final class OpenCodeSelectionLane {
  OpenCodeSelectionLane({
    required this.reader,
    required this.client,
    required this.view,
    required this.publish,
  });

  final OpenCodeSessionReader reader;
  final OpenCodeSessionLifecycleClient client;
  final SessionLiveView Function(SessionRef) view;

  /// Republishes the session's view, so its leases see the new state.
  final void Function(SessionRef) publish;
  final _entries = <SessionRef, _SelectionEntry>{};
  bool _closed = false;

  void open(SessionRef ref) => _entries.putIfAbsent(ref, _SelectionEntry.new);

  SessionSelectionState state(SessionRef ref) {
    final canonical = view(ref).state?.selection;
    final entry = _entries[ref];
    if (entry == null) return SessionSelectionState(selection: canonical);
    final change = entry.change;
    return SessionSelectionState(
      // An accepted change shows until the server reports a selection.
      selection: change != null && entry.accepted
          ? change.over(canonical)
          : canonical,
      models: entry.models,
      agents: entry.agents,
      loading: entry.reading && !entry.read,
      modelUnavailable: entry.modelUnavailable,
      agentUnavailable: entry.agentUnavailable,
      phase: entry.phase,
      notice: entry.notice,
      receipt: entry.receipt,
    );
  }

  /// A pick is offered on a live, current session without a switch in flight;
  /// an unconfirmed switch is replaced by a new pick. A switch the server took
  /// waits for its report first, so the next pick never hides it.
  bool canChange(SessionRef ref) {
    final entry = _entries[ref];
    final current = view(ref);
    return !_closed &&
        entry != null &&
        entry.phase != SessionSelectionPhase.pending &&
        !entry.accepted &&
        current.phase == SessionLivePhase.live &&
        !current.stale &&
        current.state?.selection != null;
  }

  /// Follows every published view: a new live period reads the catalog, and
  /// a server selection newer than the switch's answer settles that switch.
  void consider(SessionRef ref, SessionLiveView current) {
    final entry = _entries[ref];
    if (entry == null || _closed) return;
    if (current.phase != SessionLivePhase.live || current.stale) {
      // A read in flight may predate the reconnect, so read again after it.
      entry.needsRead = true;
      return;
    }
    final change = entry.change;
    final canonical = current.state?.selection;
    if (change != null &&
        canonical != null &&
        !identical(canonical, entry.base)) {
      if (entry.phase == SessionSelectionPhase.pending) {
        // The answer decides, but whether the server already reported this
        // switch, and replaced it since, is kept for it.
        entry.base = canonical;
        if (change.matches(canonical)) {
          entry
            ..echoed = true
            ..replaced = false;
        } else if (entry.echoed) {
          entry.replaced = true;
        }
      } else {
        entry.finish(
          change.matches(canonical)
              ? SessionSelectionNotice.none
              : entry.accepted
              ? SessionSelectionNotice.changedElsewhere
              : SessionSelectionNotice.notApplied,
        );
      }
    }
    if (entry.needsRead && !entry.reading) {
      entry.needsRead = false;
      unawaited(_readCatalog(ref, entry, current));
    }
  }

  /// Re-reads the catalog, and the record of an unconfirmed switch.
  Future<void> refresh(SessionRef ref) async {
    final entry = _entries[ref];
    final current = view(ref);
    if (entry == null ||
        _closed ||
        current.phase != SessionLivePhase.live ||
        current.stale) {
      return;
    }
    final change = entry.change;
    await Future.wait([
      if (!entry.reading) _readCatalog(ref, entry, current),
      if (change != null &&
          entry.phase == SessionSelectionPhase.unconfirmed &&
          !entry.verifying)
        _verify(ref, entry, change),
    ]);
  }

  Future<void> selectModel(
    SessionRef ref, {
    required String modelId,
    required String providerId,
    String? variant,
    required CommandId id,
  }) => _select(
    ref,
    _Change.model(modelId, providerId, variant),
    (cancellation) => client.selectModel(
      session: ref,
      id: id,
      modelId: modelId,
      providerId: providerId,
      variant: variant,
      cancellation: cancellation,
    ),
  );

  Future<void> selectAgent(
    SessionRef ref, {
    required String agentId,
    required CommandId id,
  }) => _select(
    ref,
    _Change.agent(agentId),
    (cancellation) => client.selectAgent(
      session: ref,
      id: id,
      agentId: agentId,
      cancellation: cancellation,
    ),
  );

  Future<void> _select(
    SessionRef ref,
    _Change change,
    Future<OpenCodeSessionLifecycleAttempt> Function(RequestCancellation) send,
  ) async {
    final entry = _entries[ref];
    if (entry == null || !canChange(ref)) return;
    entry
      ..finish(SessionSelectionNotice.none)
      ..receipt = null
      ..change = change
      ..phase = SessionSelectionPhase.pending
      ..base = view(ref).state?.selection;
    publish(ref);
    final OpenCodeSessionLifecycleAttempt attempt;
    try {
      attempt = await send(entry.cancellation);
    } catch (_) {
      // A defect still ends the switch, so this session's sends are never
      // held forever, and it is not swallowed.
      if (_current(ref, entry, change)) {
        entry.finish(SessionSelectionNotice.refused);
        publish(ref);
      }
      rethrow;
    }
    if (!_current(ref, entry, change)) return;
    final receipt = attempt.receipt;
    entry.receipt = receipt;
    switch (receipt.state.known) {
      case ReceiptState.accepted:
        _accept(ref, entry, change);
      case ReceiptState.rejected || ReceiptState.unavailable:
        entry.finish(SessionSelectionNotice.refused);
      default:
        final canonical = view(ref).state?.selection;
        if (entry.echoed || (canonical != null && change.matches(canonical))) {
          // The server reported the switch before its answer was lost, or
          // already holds the picked value: there is nothing to confirm.
          _accept(ref, entry, change);
          break;
        }
        // The switch may or may not have landed. The session's record
        // decides it; the switch itself is never sent again.
        entry
          ..phase = SessionSelectionPhase.unconfirmed
          ..base = canonical;
        publish(ref);
        await _verify(ref, entry, change);
        return;
    }
    publish(ref);
  }

  /// Settles an unconfirmed switch by one read of the session's record; a
  /// failed read leaves it unconfirmed.
  Future<void> _verify(
    SessionRef ref,
    _SelectionEntry entry,
    _Change change,
  ) async {
    entry.verifying = true;
    Selection? record;
    try {
      record = await reader.readSelection(
        ref,
        cancellation: entry.cancellation,
      );
    } on OpenCodeSessionReadException {
      record = null;
    } finally {
      entry.verifying = false;
    }
    if (!_current(ref, entry, change) ||
        entry.phase != SessionSelectionPhase.unconfirmed) {
      return;
    }
    if (record == null) return publish(ref);
    if (change.matches(record)) {
      _accept(ref, entry, change);
    } else {
      entry.finish(SessionSelectionNotice.notApplied);
    }
    publish(ref);
  }

  /// The server took [change]: it shows until the server reports a selection
  /// newer than the current one.
  void _accept(SessionRef ref, _SelectionEntry entry, _Change change) {
    final canonical = view(ref).state?.selection;
    if (canonical != null && change.matches(canonical)) {
      // The server already reported it, before the answer.
      entry.finish(SessionSelectionNotice.none);
      return;
    }
    if (entry.replaced) {
      // It was reported, then replaced by another pick before the answer.
      entry.finish(SessionSelectionNotice.changedElsewhere);
      return;
    }
    entry
      ..phase = SessionSelectionPhase.idle
      ..accepted = true
      ..base = canonical;
  }

  bool _current(SessionRef ref, _SelectionEntry entry, _Change change) =>
      !_closed &&
      identical(_entries[ref], entry) &&
      identical(entry.change, change);

  Future<void> _readCatalog(
    SessionRef ref,
    _SelectionEntry entry,
    SessionLiveView current,
  ) async {
    final directory = current.state?.info?.project?.canonicalDirectory;
    if (directory == null) {
      entry
        ..read = true
        ..models = const []
        ..agents = const []
        ..modelUnavailable = SessionSelectionUnavailable.locationUnknown
        ..agentUnavailable = SessionSelectionUnavailable.locationUnknown;
      return publish(ref);
    }
    entry.reading = true;
    publish(ref);
    final (models, modelFailure) = await _attempt(
      () => reader.readModels(directory, cancellation: entry.cancellation),
    );
    final (agents, agentFailure) = await _attempt(
      () => reader.readAgents(directory, cancellation: entry.cancellation),
    );
    entry.reading = false;
    if (_closed || !identical(_entries[ref], entry)) return;
    entry
      ..read = true
      ..models = models ?? const []
      ..agents = agents ?? const []
      ..modelUnavailable =
          modelFailure ??
          (models!.isEmpty ? SessionSelectionUnavailable.emptyCatalog : null)
      ..agentUnavailable =
          agentFailure ??
          (agents!.isEmpty ? SessionSelectionUnavailable.emptyCatalog : null);
    publish(ref);
  }

  static Future<(List<T>?, SessionSelectionUnavailable?)> _attempt<T>(
    Future<List<T>> Function() read,
  ) async {
    try {
      return (await read(), null);
    } on OpenCodeSessionReadException catch (error) {
      return (
        null,
        switch (error.failure) {
          OpenCodeSessionReadFailure.notFound =>
            SessionSelectionUnavailable.routeAbsent,
          OpenCodeSessionReadFailure.authenticationRequired =>
            SessionSelectionUnavailable.authenticationRequired,
          OpenCodeSessionReadFailure.incompatibleResponse ||
          OpenCodeSessionReadFailure.bodyTooLarge ||
          OpenCodeSessionReadFailure.invalidRequest =>
            SessionSelectionUnavailable.catalogUnreadable,
          _ => SessionSelectionUnavailable.serviceUnavailable,
        },
      );
    }
  }

  void release(SessionRef ref) => _entries.remove(ref)?.dispose();

  void close() {
    _closed = true;
    for (final entry in _entries.values) {
      entry.dispose();
    }
    _entries.clear();
  }
}

/// One explicit switch: the model reference or the agent, never both.
final class _Change {
  const _Change.model(String this.modelId, String this.providerId, this.variant)
    : agentId = null;
  const _Change.agent(String this.agentId)
    : modelId = null,
      providerId = null,
      variant = null;

  final String? modelId;
  final String? providerId;
  final String? variant;
  final String? agentId;

  bool get isModel => agentId == null;

  bool matches(Selection selection) => isModel
      ? selection.modelId == modelId &&
            selection.modelProviderId == providerId &&
            selection.modelVariant == variant
      : selection.agentId == agentId;

  /// [selection] with this switch's half replaced.
  Selection over(Selection? selection) => Selection(
    modelId: isModel ? modelId : selection?.modelId,
    modelProviderId: isModel ? providerId : selection?.modelProviderId,
    modelVariant: isModel ? variant : selection?.modelVariant,
    agentId: isModel ? selection?.agentId : agentId,
    effort: selection?.effort,
    permissionMode: selection?.permissionMode,
    metadata: selection?.metadata,
  );
}

final class _SelectionEntry {
  final cancellation = RequestCancellation();
  bool needsRead = true;
  bool reading = false;

  /// The catalog was read at least once.
  bool read = false;
  bool verifying = false;
  List<ModelEntry> models = const [];
  List<CatalogEntry> agents = const [];
  SessionSelectionUnavailable? modelUnavailable;
  SessionSelectionUnavailable? agentUnavailable;
  SessionSelectionPhase phase = SessionSelectionPhase.idle;
  SessionSelectionNotice notice = SessionSelectionNotice.none;
  CommandReceipt? receipt;

  /// The last explicit switch while it is pending, unconfirmed or accepted
  /// and not yet reported by the server.
  _Change? change;

  /// The server took [change].
  bool accepted = false;

  /// While [change] is pending: the server reported it, and then reported a
  /// different value for the same half.
  bool echoed = false;
  bool replaced = false;

  /// The last server selection [change] has seen; once answered, only a
  /// different one settles it.
  Selection? base;

  void finish(SessionSelectionNotice outcome) {
    change = null;
    accepted = false;
    echoed = false;
    replaced = false;
    base = null;
    phase = SessionSelectionPhase.idle;
    notice = outcome;
  }

  void dispose() => cancellation.cancel();
}
