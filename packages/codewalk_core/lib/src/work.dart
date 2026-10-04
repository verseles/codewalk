import 'errors.dart';
import 'identity.dart';
import 'values.dart';

enum WorkStatus {
  queued,
  running,
  waiting,
  completed,
  failed,
  cancelled,
  unknown,
}

/// The scope of the observation, not a promise about another owner's execution.
enum CompletionScope { work, child, session, sessionTree, notice, unknown }

/// A child or background job can remain active while its parent is idle.
///
/// A parent completion notice can arrive before the child's own terminal event.
/// [status] describes this observation's [completionScope]; consumers must not
/// promote a [CompletionScope.notice] into a terminal child/session outcome.
final class WorkItem {
  const WorkItem({
    required this.id,
    required this.owner,
    required this.status,
    required this.completionScope,
    this.child,
    this.parent,
    this.title,
    this.error,
    this.source,
  });

  final WorkId id;
  final DomainOwner owner;
  final SessionRef? child;
  final SessionRef? parent;
  final OpenValue<WorkStatus> status;
  final OpenValue<CompletionScope> completionScope;
  final String? title;
  final ErrorInfo? error;
  final SourceProvenance? source;
}

enum PlanStatus { pending, inProgress, completed, cancelled, unknown }

/// A structured native plan entry. Text is never parsed to invent a plan.
final class PlanEntry {
  PlanEntry({
    required this.id,
    required this.title,
    required this.status,
    this.metadata,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty');
    }
  }

  final String id;
  final String title;
  final OpenValue<PlanStatus> status;
  final CanonicalValue? metadata;
}

/// A complete structured level-set; replacing it does not merge old entries.
final class PlanSnapshot {
  PlanSnapshot({
    required this.owner,
    required Iterable<PlanEntry> entries,
    this.source,
  }) : entries = immutableList(entries);

  final DomainOwner owner;
  final List<PlanEntry> entries;
  final SourceProvenance? source;
}
