import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';

import '../../shared/sessions/session_catalog_changes.dart';

/// The catalog's hold on one profile's stream.
///
/// The feed is the endpoint's single stream: the lease only forwards the
/// owner's payload-free catalog signal and keeps the profile alive while the
/// catalog needs it.
final class OpenCodeCatalogLease implements SessionCatalogChanges {
  OpenCodeCatalogLease(this._owner, this._release) {
    _changes = _owner.catalogChanges.listen(
      (change) => _add(switch (change) {
        OpenCodeCatalogChange.started ||
        OpenCodeCatalogChange.waiting => const SessionActivityChanged(),
        _ => const SessionCatalogChanged(),
      }),
    );
    // Only a stream-level update describes the endpoint's stream: a
    // per-session degradation leaves the stream live.
    _connection = _owner.updates
        .where((update) => update is OpenCodeConnectionUpdated)
        .where(
          (update) => (update as OpenCodeConnectionUpdated).session == null,
        )
        .listen((update) {
          final kind = (update as OpenCodeConnectionUpdated).kind;
          _add(SessionCatalogConnection(kind == ConnectionKind.live));
          if (kind == ConnectionKind.authRequired ||
              kind == ConnectionKind.incompatible) {
            // A terminal stream ends the feed: the catalog drops the lease
            // and re-acquires one on the next read.
            unawaited(_controller.close());
          }
        });
  }

  final void Function(OpenCodeCatalogLease) _release;
  final OpenCodeStreamOwner _owner;
  final _controller = StreamController<SessionCatalogSignal>.broadcast();
  late final StreamSubscription<OpenCodeCatalogChange> _changes;
  late final StreamSubscription<OpenCodeStreamUpdate> _connection;
  bool _closed = false;

  @override
  Stream<SessionCatalogSignal> get signals => Stream.multi((controller) {
    // A subscriber that arrives late learns the current state first: a
    // broadcast controller would drop it.
    final kind = _owner.connectionKind;
    if (kind != null) {
      controller.add(SessionCatalogConnection(kind == ConnectionKind.live));
    }
    final subscription = _controller.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
  });

  void _add(SessionCatalogSignal signal) {
    if (!_closed && !_controller.isClosed) _controller.add(signal);
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    unawaited(_changes.cancel());
    unawaited(_connection.cancel());
    unawaited(_controller.close());
    _release(this);
  }
}
