import 'capabilities.dart';
import 'catalog.dart';
import 'commands.dart';
import 'events.dart';
import 'identity.dart';
import 'interactions.dart';
import 'lifecycle.dart';
import 'session.dart';
import 'values.dart';
import 'work.dart';
import 'workspace.dart';

/// Capability denial must precede native mutation; optional facets are absent
/// when unsupported. Opening history and detaching never change execution.
abstract interface class HarnessAdapter {
  HarnessDescriptor get descriptor;
  Stream<ConnectionState> get connection;
  Future<CapabilitySet> capabilities({DomainOwner? owner});
  Future<Page<SessionSummary>> listSessions(SessionQuery query);
  Future<SessionHandle> open(SessionRef ref, OpenIntent intent);
  Future<CreateResult> create(CreateSession request);
  CatalogFacet get catalog;
  WorkspaceFacet? get workspace;
  InteractionFacet? get interactions;
}

final class CreateResult {
  CreateResult({required this.receipt, this.handle}) {
    if (handle != null &&
        (!receipt.admissionKnown ||
            !receipt.owner.isKnown ||
            receipt.owner.harness != handle!.ref.harnessRef ||
            receipt.nativeRef != handle!.ref.nativeId)) {
      throw ArgumentError(
        'Create handle requires known admission in its original harness',
      );
    }
  }
  final CommandReceipt receipt;
  final SessionHandle? handle;
}

enum InterruptKind { turn, child, allBackground, unknown }

final class InterruptTarget {
  const InterruptTarget({required this.kind, this.child, this.turn});
  final OpenValue<InterruptKind> kind;
  final SessionRef? child;
  final TurnId? turn;
}

abstract interface class SessionHandle {
  SessionRef get ref;
  Stream<SessionEvent> get events;
  Future<SessionSnapshot> snapshot({HistoryCursor? before, int limit = 50});
  Future<CommandReceipt> send(
    PromptDraft draft, {
    required CommandId id,
    OpenValue<Delivery>? delivery,
  });
  Future<CommandReceipt> interrupt(
    InterruptTarget target, {
    required CommandId id,
  });
  Future<CommandReceipt> respond(
    InteractionId interaction,
    InteractionResponse response, {
    required CommandId id,
  });
  Future<CommandReceipt> select(
    SelectionChange change, {
    required CommandId id,
  });
  QueueFacet? get queue;
  UndoFacet? get undo;
  WorkFacet? get work;
  LifecycleFacet? get lifecycle;
  Future<void> detach();
}

abstract interface class InteractionFacet {
  Future<Page<InteractionRequest>> pending(DomainOwner owner);
  Future<CommandReceipt> respond(
    DomainOwner owner,
    InteractionId interaction,
    InteractionResponse response, {
    required CommandId id,
  });
}

abstract interface class QueueFacet {
  Future<CommandReceipt> cancel(ItemId input, {required CommandId id});
  Future<CommandReceipt> edit(
    ItemId input,
    PromptDraft replacement, {
    required CommandId id,
  });
  Future<CommandReceipt> reorder(List<ItemId> inputs, {required CommandId id});
}

final class RevertRequest {
  const RevertRequest({required this.boundary, required this.includeFiles});
  final ItemId boundary;
  final bool includeFiles;
}

abstract interface class UndoFacet {
  Future<CommandReceipt> stage(RevertRequest request, {required CommandId id});
  Future<CommandReceipt> clear({required CommandId id});
  Future<CommandReceipt> commit({required CommandId id});
}

abstract interface class WorkFacet {
  Future<List<WorkItem>> list();
  Future<CommandReceipt> stop(WorkId work, {required CommandId id});
  Future<CommandReceipt> moveToBackground({required CommandId id});
  Future<CommandReceipt> sendToChild(
    SessionRef child,
    PromptDraft draft, {
    required CommandId id,
  });
}

final class ForkRequest {
  const ForkRequest({required this.id, this.before});
  final CommandId id;
  final ItemId? before;
}

abstract interface class LifecycleFacet {
  Future<CommandReceipt> resume({required CommandId id});
  Future<CreateResult> fork(ForkRequest request);
  Future<CommandReceipt> archive({required CommandId id});
  Future<CommandReceipt> delete({required CommandId id});
}
