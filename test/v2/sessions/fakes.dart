import 'dart:async';

import 'package:codewalk/features/hosts/hosts_controller.dart';
import 'package:codewalk/features/sessions/sessions_controller.dart';
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

class CatalogSource implements SessionCatalogSource {
  CatalogSource(EndpointProfile profile)
    : harness = HarnessRef(HostId(profile.id), HarnessInstanceId(profile.id));
  @override
  final HarnessRef harness;
  final tasks = <CatalogTask>[];
  final queries = <SessionQuery>[];
  int closes = 0;
  @override
  CatalogTask list(SessionQuery query) {
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
  }) => SessionSummary(
    info: SessionInfo(
      ref: SessionRef(harness.host, harness.harness, 'ses_$id'),
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
  );

  void respond(List<SessionSummary> rows, {String? next}) =>
      tasks.last.completion.complete(Page(items: rows, nextCursor: next));
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
  }) {
    hosts = HostsController(repository: repository, prober: FakeProber());
    sessions = SessionsController(
      hosts: hosts,
      sourceFactory: create,
      changesFactory: withFeed ? (_, _) => _openFeed() : null,
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
