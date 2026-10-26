import 'dart:async';

import 'package:codewalk/features/hosts/hosts_controller.dart';
import 'package:codewalk/features/sessions/sessions_controller.dart';
import 'package:codewalk/shared/sessions/session_actions.dart';
import 'package:codewalk/shared/sessions/session_activity.dart';
import 'package:codewalk/shared/sessions/session_catalog_changes.dart';
import 'package:codewalk/shared/sessions/session_catalog_source.dart';
import 'package:codewalk_core/codewalk_core.dart';

import '../hosts/fakes.dart';

EndpointProfile profile(String id) => EndpointProfile(
  id: 'profile_$id',
  label: 'Server $id',
  endpoint: Uri.parse('http://127.0.0.1:4096/proxy/'),
);

class GatedProfiles extends MemoryProfiles {
  Completer<EndpointCredential?>? credentialGate;
  String? unreadable;
  @override
  Future<EndpointCredential?> readCredential(EndpointProfile profile) async {
    if (profile.id == unreadable) throw StateError('private credential error');
    return credentialGate == null
        ? super.readCredential(profile)
        : credentialGate!.future;
  }
}

// Cancellation deliberately does not settle the future: controllers must reject
// late success/error independently of what the transport manages to abort.
class CatalogTask implements SessionCatalogTask {
  final completion = Completer<Page<SessionSummary>>();
  bool cancelled = false;
  @override
  Future<Page<SessionSummary>> get result => completion.future;
  @override
  void cancel() => cancelled = true;
}

class CatalogRead<T> implements SessionCatalogRead<T> {
  final completion = Completer<T>();
  bool cancelled = false;
  @override
  Future<T> get result => completion.future;
  @override
  void cancel() => cancelled = true;
}

class ReadTask implements SessionReadTask {
  final completion = Completer<SessionSummary>();
  bool cancelled = false;
  @override
  Future<SessionSummary> get result => completion.future;
  @override
  void cancel() => cancelled = true;
}

class CatalogSource implements SessionCatalogSource {
  CatalogSource(EndpointProfile profile)
    : harness = HarnessRef(HostId(profile.id), HarnessInstanceId(profile.id));
  @override
  final HarnessRef harness;
  final tasks = <CatalogTask>[];
  final queries = <SessionQuery>[];
  final reads = <(SessionRef, ReadTask)>[];
  int closes = 0;
  /// Answers a read of one project context at once with the rows of the
  /// whole-server answers in that directory, as a consistent server would.
  /// Tests that drive the context reads by hand turn it off.
  bool autoContexts = true;
  final contextQueries = <SessionQuery>[];
  List<SessionSummary> _served = const [];

  /// The rows of the whole-server answers so far.
  List<SessionSummary> get served => _served;

  @override
  CatalogTask list(SessionQuery query) {
    if (autoContexts && query.project != null) {
      contextQueries.add(query);
      final directory = query.project!.canonicalDirectory;
      return CatalogTask()
        ..completion.complete(
          Page(
            items: [
              for (final row in _served)
                if (row.info.project?.canonicalDirectory == directory) row,
            ],
          ),
        );
    }
    queries.add(query);
    final task = CatalogTask();
    tasks.add(task);
    return task;
  }

  SessionSummary row(
    String id, {
    String? title,
    String? directory,
    String? upstream,
    OwnershipInfo? ownership,
    String? parent,
    SessionViewMarker? view,
  }) => SessionSummary(
    info: SessionInfo(
      ref: SessionRef(harness.host, harness.harness, 'ses_$id'),
      lineage: SessionLineage(
        parent: parent == null
            ? null
            : SessionRef(harness.host, harness.harness, 'ses_$parent'),
      ),
      title: title ?? id,
      ownership:
          ownership ?? const OwnershipInfo.unknown(reason: 'not observed'),
      project: directory == null
          ? null
          : ProjectRef(
              harness.host,
              directory,
              upstreamProjectId: upstream,
            ),
    ),
    updatedAt: DateTime.utc(2026, 10, 12),
    view: view,
  );

  @override
  ReadTask read(SessionRef ref) {
    final task = ReadTask();
    reads.add((ref, task));
    return task;
  }

  /// What the activity reads answer, the directories they asked for and a
  /// gate that holds them.
  SessionActivity activityAnswer = const SessionActivity();
  Completer<void>? activityGate;
  final activityRequests = <String?>[];
  @override
  Future<SessionActivity> activity({String? directory}) async {
    activityRequests.add(directory);
    await activityGate?.future;
    return SessionActivity(
      running: activityAnswer.running,
      directory: directory,
      waiting: activityAnswer.waiting,
    );
  }

  /// The directory reads, each held until a test settles it.
  final projectReads = <CatalogRead<List<ProjectRef>>>[];
  final locationReads = <(String?, CatalogRead<ProjectRef>)>[];
  final listReads = <(String, String?, CatalogRead<List<FileEntry>>)>[];
  final findReads = <(String, String, CatalogRead<List<FileEntry>>)>[];
  @override
  CatalogRead<List<ProjectRef>> projects() {
    final read = CatalogRead<List<ProjectRef>>();
    projectReads.add(read);
    return read;
  }

  @override
  CatalogRead<ProjectRef> location({String? directory}) {
    final read = CatalogRead<ProjectRef>();
    locationReads.add((directory, read));
    return read;
  }

  @override
  CatalogRead<List<FileEntry>> listDirectory(
    String directory, {
    String? path,
  }) {
    final read = CatalogRead<List<FileEntry>>();
    listReads.add((directory, path, read));
    return read;
  }

  @override
  CatalogRead<List<FileEntry>> findDirectories(
    String directory,
    String query,
  ) {
    final read = CatalogRead<List<FileEntry>>();
    findReads.add((directory, query, read));
    return read;
  }

  void respond(List<SessionSummary> rows, {String? next}) {
    final query = queries.last;
    if (query.project == null) {
      _served = [if (query.cursor != null) ..._served, ...rows];
    }
    tasks.last.completion.complete(Page(items: rows, nextCursor: next));
  }
  void fail(SessionCatalogFailure failure) =>
      tasks.last.completion.completeError(SessionCatalogException(failure));
  @override
  void close() => closes++;
}

class CatalogRig {
  CatalogRig({
    DateTime Function()? now,
    Duration liveDebounce = Duration.zero,
    Duration liveMinInterval = Duration.zero,
    bool withFeed = true,
    SessionActionSource? actions,
  }) {
    hosts = HostsController(repository: repository, prober: FakeProber());
    sessions = SessionsController(
      hosts: hosts,
      sourceFactory: create,
      changesFactory: withFeed ? (_, _) => _openFeed() : null,
      actionFactory: actions == null ? null : (_, _) => actions,
      now: now,
      liveDebounce: liveDebounce,
      liveMinInterval: liveMinInterval,
    );
  }
  final repository = GatedProfiles();
  late final HostsController hosts;
  late final SessionsController sessions;
  final sources = <CatalogSource>[];

  /// The endpoint's lifecycle feeds, one per acquisition; the tests drive
  /// the newest one by hand.
  final feeds = <LiveCatalogChanges>[];

  /// Holds the feed acquisition open, so a test can observe what happens
  /// while it is still opening.
  Completer<void>? feedGate;

  Future<SessionCatalogChanges> _openFeed() async {
    final gate = feedGate;
    if (gate != null) await gate.future;
    return createFeed();
  }

  LiveCatalogChanges get feed => feeds.last;

  LiveCatalogChanges createFeed() {
    final created = LiveCatalogChanges();
    feeds.add(created);
    return created;
  }

  CatalogSource create(EndpointProfile profile, EndpointCredential credential) {
    final source = CatalogSource(profile);
    sources.add(source);
    return source;
  }

  Future<void> save(String id) => repository.save(profile(id), 'fake-$id');
  void dispose() {
    sessions.dispose();
    hosts.dispose();
  }
}

/// The catalog feed of an endpoint, driven by hand.
class LiveCatalogChanges implements SessionCatalogChanges {
  final _controller = StreamController<SessionCatalogSignal>.broadcast();
  int closes = 0;

  @override
  Stream<SessionCatalogSignal> get signals => _controller.stream;

  void emit(SessionCatalogSignal signal) => _controller.add(signal);

  @override
  void close() {
    closes++;
    unawaited(_controller.close());
  }
}


/// A scripted session action source for the widget tests.
///
/// It answers the platform's contract without a transport: the support, the
/// unread marker, the child count, the commands and the local hide.
final class FakeActionSource implements SessionActionSource {
  FakeActionSource({
    this.endpointSupport = const SessionActionSupport(
      SessionActionReason.none,
    ),
    this.children = 0,
    Map<String, SessionViewState> viewStates = const {},
  }) : viewStates = {...viewStates};

  /// The endpoint's support for the actions.
  SessionActionSupport endpointSupport;

  /// The direct children of a row, or null when the count cannot be read.
  int? children;

  /// The unread marker of a row, by its storage key.
  Map<String, SessionViewState> viewStates = {};

  /// The outcome of every command, by its name.
  final outcomes = <String, SessionActionOutcome>{};

  /// How long the create waits before it answers.
  Duration createDelay = Duration.zero;

  /// The commands the tests received, in order.
  final calls = <String>[];

  /// The titles the renames carried.
  final titles = <String>[];

  /// The rows marked as viewed, with the idle transition each one carried.
  final viewed = <(String, DateTime?)>[];

  /// The sessions hidden in CodeWalk, by their storage key.
  final hidden = <String>{};

  /// Whether the local hide can be read and written.
  @override
  bool hideAvailable = true;

  /// Whether the local hide state could not be read.
  @override
  bool hideUnreadable = false;

  @override
  final HarnessRef harness = const HarnessRef(
    HostId('host-a'),
    HarnessInstanceId('native-a'),
  );

  @override
  Future<SessionActionSupport> support() async => endpointSupport;

  @override
  SessionViewState viewState(SessionSummary row) =>
      viewStates[row.info.ref.storageKey] ?? SessionViewState.unknown;

  @override
  Future<int?> childCount(SessionSummary row) async => children;

  /// The directories the created sessions asked for.
  final created = <String>[];

  /// The titles the created sessions carried.
  final createdTitles = <String?>[];

  /// The created session reference to return, if any.
  SessionRef? createdSessionRef;

  @override
  Future<SessionCreateResult> create({
    required String directory,
    String? title,
  }) async {
    calls.add('create');
    created.add(directory);
    createdTitles.add(title);
    if (createDelay > Duration.zero) {
      await Future<void>.delayed(createDelay);
    }
    final outcome = outcomes['create'] ?? SessionActionOutcome.accepted;
    return SessionCreateResult(outcome, createdSessionRef);
  }

  @override
  Future<SessionActionOutcome> rename(SessionSummary row, String title) async {
    calls.add('rename');
    titles.add(title);
    return outcomes['rename'] ?? SessionActionOutcome.accepted;
  }

  @override
  Future<SessionActionOutcome> delete(SessionSummary row) async {
    calls.add('delete');
    return outcomes['delete'] ?? SessionActionOutcome.accepted;
  }

  @override
  Future<SessionActionOutcome> fork(SessionSummary row) async {
    calls.add('fork');
    return outcomes['fork'] ?? SessionActionOutcome.accepted;
  }

  @override
  Future<SessionActionOutcome> markViewed(SessionSummary row) async {
    calls.add('markViewed');
    viewed.add((row.info.ref.storageKey, row.view?.idleAt));
    return outcomes['markViewed'] ?? SessionActionOutcome.accepted;
  }

  @override
  bool isHidden(SessionSummary row) => hidden.contains(row.info.ref.storageKey);

  @override
  Future<bool> setHidden(
    SessionSummary row, {
    required bool hidden,
  }) async {
    calls.add(hidden ? 'hide' : 'unhide');
    if (hidden) {
      this.hidden.add(row.info.ref.storageKey);
    } else {
      this.hidden.remove(row.info.ref.storageKey);
    }
    return true;
  }

  @override
  void close() {}
}
