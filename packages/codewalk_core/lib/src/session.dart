import 'events.dart';
import 'identity.dart';
import 'interactions.dart';
import 'lifecycle.dart';
import 'ownership.dart';
import 'timeline.dart';
import 'usage.dart';
import 'values.dart';
import 'work.dart';

final class HistoryCursor {
  HistoryCursor(String value) : value = requireText(value);
  final String value;
}

final class Page<T> {
  Page({required Iterable<T> items, this.nextCursor, this.boundary})
    : items = immutableList(items);
  final List<T> items;
  final String? nextCursor;
  final SnapshotBoundary? boundary;
}

enum SnapshotAuthority { authoritative, derived, local, unknown }

/// Client causal bookkeeping captured BEFORE starting one read. This is not a
/// source-provided watermark. Non-atomic reads each retain their own boundary.
final class SnapshotBoundary {
  SnapshotBoundary({
    required this.owner,
    required String hydrationGeneration,
    required this.readStart,
    required this.readStartedAt,
    this.readCompletedAt,
    this.source,
    this.authority = const OpenValue.known(SnapshotAuthority.unknown),
  }) : hydrationGeneration = requireText(hydrationGeneration) {
    if (readCompletedAt?.isBefore(readStartedAt) == true) {
      throw ArgumentError('Read completion precedes its start');
    }
    if (source != null && owner.isKnown && owner.harness != source!.harness) {
      throw ArgumentError('Snapshot source belongs to another owner');
    }
  }
  final DomainOwner owner;
  final String hydrationGeneration;
  final StreamPosition readStart;
  final DateTime readStartedAt;
  final DateTime? readCompletedAt;
  final SourceProvenance? source;
  final OpenValue<SnapshotAuthority> authority;
}

final class SnapshotValue<T> {
  const SnapshotValue({required this.value, required this.boundary});
  final T value;
  final SnapshotBoundary boundary;
}

final class SnapshotCollection<T> {
  SnapshotCollection({
    required Iterable<T> values,
    required this.boundary,
    this.complete = true,
  }) : values = immutableList(values);
  final List<T> values;
  final SnapshotBoundary boundary;
  final bool complete;
}

final class SessionInfo {
  const SessionInfo({
    required this.ref,
    required this.title,
    required this.ownership,
    this.project,
    this.lineage = const SessionLineage(),
    this.metadata,
  });
  final SessionRef ref;
  final String title;
  final OwnershipInfo ownership;
  final ProjectRef? project;
  final SessionLineage lineage;
  final CanonicalValue? metadata;
}

final class SessionSummary {
  const SessionSummary({required this.info, this.execution, this.updatedAt});
  final SessionInfo info;
  final ExecutionState? execution;
  final DateTime? updatedAt;
}

final class SessionQuery {
  SessionQuery({
    this.project,
    this.cursor,
    this.limit = 50,
    this.activeOnly = false,
  }) {
    if (limit <= 0) throw ArgumentError('Session page limit must be positive');
  }
  final ProjectRef? project;
  final String? cursor;
  final int limit;
  final bool activeOnly;
}

/// These intents observe only. Continuing inactive work is LifecycleFacet.resume
/// and carries its own command ID and uncertain receipt.
enum OpenIntent { viewHistory, attachLive }

final class Selection {
  const Selection({
    this.modelId,
    this.agentId,
    this.effort,
    this.permissionMode,
    this.metadata,
  });
  final String? modelId;
  final String? agentId;
  final String? effort;
  final String? permissionMode;
  final CanonicalValue? metadata;
}

final class SelectionChange {
  const SelectionChange({required this.selection});
  final Selection selection;
}

final class PendingInput {
  const PendingInput({
    required this.id,
    required this.text,
    required this.delivery,
    this.commandId,
  });
  final ItemId id;
  final String text;
  final OpenValue<Delivery> delivery;
  final CommandId? commandId;
}

final class PromptDraft {
  PromptDraft({
    required this.text,
    Iterable<AttachmentRef> attachments = const [],
    Iterable<MentionRef> mentions = const [],
    this.selection,
    this.metadata,
  }) : attachments = immutableList(attachments),
       mentions = immutableList(mentions);
  final String text;
  final List<AttachmentRef> attachments;
  final List<MentionRef> mentions;
  final Selection? selection;
  final CanonicalValue? metadata;
}

final class CreateSession {
  CreateSession({
    required this.id,
    required this.harness,
    required this.project,
    this.title,
    this.selection,
    this.metadata,
  }) {
    if (harness.host != project.host) {
      throw ArgumentError('Create project belongs to another host');
    }
  }
  final CommandId id;
  final HarnessRef harness;
  final ProjectRef project;
  final String? title;
  final Selection? selection;
  final CanonicalValue? metadata;
}

/// Every independently fetched collection carries its own client read barrier.
/// Reducers overlay newer events; the model does not invent upstream atomicity.
final class SessionSnapshot {
  SessionSnapshot({
    required this.ref,
    required String hydrationGeneration,
    this.info,
    this.execution,
    this.timeline,
    this.pending,
    this.interactions,
    this.work,
    this.plan,
    this.usage,
    this.selection,
    this.revert,
    this.nextHistoryCursor,
    this.hasMoreHistory = false,
  }) : hydrationGeneration = requireText(hydrationGeneration) {
    final boundaries = <SnapshotBoundary?>[
      info?.boundary,
      execution?.boundary,
      timeline?.boundary,
      pending?.boundary,
      interactions?.boundary,
      work?.boundary,
      plan?.boundary,
      usage?.boundary,
      selection?.boundary,
      revert?.boundary,
    ];
    for (final boundary in boundaries.whereType<SnapshotBoundary>()) {
      if (boundary.hydrationGeneration != hydrationGeneration ||
          boundary.owner is! SessionOwner ||
          (boundary.owner as SessionOwner).session != ref) {
        throw ArgumentError(
          'Snapshot collection belongs to another session or hydration generation',
        );
      }
    }
    if (info != null && info!.value.ref != ref) {
      throw ArgumentError('Snapshot info belongs to another session');
    }
  }
  final SessionRef ref;
  final String hydrationGeneration;
  final SnapshotValue<SessionInfo>? info;
  final SnapshotValue<ExecutionState>? execution;
  final SnapshotCollection<TimelineItem>? timeline;
  final SnapshotCollection<PendingInput>? pending;
  final SnapshotCollection<InteractionRequest>? interactions;
  final SnapshotCollection<WorkItem>? work;
  final SnapshotValue<PlanSnapshot>? plan;
  final SnapshotCollection<UsageObservation>? usage;
  final SnapshotValue<Selection>? selection;
  final SnapshotValue<RevertState>? revert;
  final HistoryCursor? nextHistoryCursor;
  final bool hasMoreHistory;
}
