import 'errors.dart';
import 'identity.dart';
import 'interactions.dart';
import 'lifecycle.dart';
import 'session.dart';
import 'timeline.dart';
import 'usage.dart';
import 'values.dart';
import 'work.dart';

enum DeltaField { text, reasoning, toolInput, other }

/// Position in a canonical observation stream, not an upstream log sequence.
/// Upstream aggregate sequences can skip internal records and stay in
/// [SourceProvenance].
final class StreamPosition {
  StreamPosition({required this.id, required this.epoch, required this.seq}) {
    if (id.isEmpty || epoch.isEmpty || seq.isNegative) {
      throw ArgumentError(
        'Stream identity, epoch and nonnegative seq required',
      );
    }
  }

  factory StreamPosition.fromJson(Object? value) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw const FormatException('StreamPosition must be an object');
    }
    final id = value['id'];
    final epoch = value['epoch'];
    final seq = value['seq'];
    if (value['version'] is! int ||
        value['version'] != 1 ||
        id is! String ||
        id.isEmpty ||
        epoch is! String ||
        epoch.isEmpty ||
        seq is! String ||
        RegExp(r'^(0|[1-9][0-9]*)$').stringMatch(seq) != seq) {
      throw const FormatException('Invalid StreamPosition');
    }
    return StreamPosition(id: id, epoch: epoch, seq: BigInt.parse(seq));
  }

  final String id;
  final String epoch;
  final BigInt seq;

  Map<String, Object?> toJson() => {
    'version': 1,
    'id': id,
    'epoch': epoch,
    'seq': seq.toString(),
  };

  @override
  bool operator ==(Object other) =>
      other is StreamPosition &&
      id == other.id &&
      epoch == other.epoch &&
      seq == other.seq;

  @override
  int get hashCode => Object.hash(id, epoch, seq);
}

/// An explicit owner allows host/project/global events without inventing a
/// session. Child origin and native source provenance remain separate.
final class EventMeta {
  EventMeta({
    required this.owner,
    required this.position,
    required this.receivedAt,
    required this.source,
    this.rawRef,
  }) {
    if (owner.isKnown && owner.harness != source.harness) {
      throw ArgumentError(
        'Event owner and source belong to different harnesses',
      );
    }
  }

  final DomainOwner owner;
  final StreamPosition position;
  final DateTime receivedAt;
  final SourceProvenance source;
  final DiagnosticRef? rawRef;
}

sealed class SessionEvent {
  const SessionEvent({required this.meta});

  final EventMeta meta;
}

final class ItemUpserted extends SessionEvent {
  const ItemUpserted({required super.meta, required this.item});

  final TimelineItem item;
}

/// Append only to an open item with this generation. Authoritative completion
/// is represented by [ItemUpserted] with the complete replacement value.
final class ItemDelta extends SessionEvent {
  ItemDelta({
    required super.meta,
    required this.itemId,
    required this.field,
    required this.text,
    required String generation,
  }) : generation = requireText(generation, 'generation') {
    requireText(itemId.value, 'itemId');
  }

  final ItemId itemId;
  final OpenValue<DeltaField> field;
  final String text;
  final String generation;
}

final class ItemsRemoved extends SessionEvent {
  const ItemsRemoved({required super.meta, required this.fromItemId});

  final ItemId fromItemId;
}

final class ExecutionChanged extends SessionEvent {
  const ExecutionChanged({required super.meta, required this.state});

  final ExecutionState state;
}

/// Provider retry scheduling is distinct from command admission/replay.
final class RetryScheduled extends SessionEvent {
  RetryScheduled({
    required super.meta,
    required this.attempt,
    required this.at,
    required this.error,
  }) {
    if (attempt < 0) {
      throw ArgumentError.value(attempt, 'attempt', 'Must be nonnegative');
    }
  }

  final int attempt;
  final DateTime at;
  final ErrorInfo error;
}

/// Level-set observation: replace the pending collection, never merge it.
final class PendingInputChanged extends SessionEvent {
  PendingInputChanged({
    required super.meta,
    required Iterable<PendingInput> items,
  }) : items = immutableList(items);

  final List<PendingInput> items;
}

final class InteractionOpened extends SessionEvent {
  const InteractionOpened({required super.meta, required this.request});

  final InteractionRequest request;
}

final class InteractionResolved extends SessionEvent {
  const InteractionResolved({required super.meta, required this.resolution});

  final InteractionResolution resolution;
}

/// Level-set observation; completion ownership is carried by each work item.
final class WorkChanged extends SessionEvent {
  WorkChanged({required super.meta, required Iterable<WorkItem> items})
    : items = immutableList(items);

  final List<WorkItem> items;
}

final class PlanChanged extends SessionEvent {
  const PlanChanged({required super.meta, required this.plan});

  final PlanSnapshot plan;
}

final class UsageObserved extends SessionEvent {
  const UsageObserved({required super.meta, required this.observation});

  final UsageObservation observation;
}

final class SelectionChanged extends SessionEvent {
  const SelectionChanged({required super.meta, required this.selection});

  final Selection selection;
}

final class RevertChanged extends SessionEvent {
  const RevertChanged({required super.meta, required this.state});

  final RevertState state;
}

final class SessionInfoChanged extends SessionEvent {
  const SessionInfoChanged({required super.meta, required this.info});

  final SessionInfo info;
}

final class ResyncRequired extends SessionEvent {
  const ResyncRequired({required super.meta, required this.reason});

  final String reason;
}

/// Unknown source events remain observations, not invented timeline content.
/// Raw content must already be bounded and sanitized by the adapter.
final class UnknownEvent extends SessionEvent {
  const UnknownEvent({
    required super.meta,
    required this.rawType,
    required this.raw,
  });

  final String rawType;
  final CanonicalValue raw;
}
