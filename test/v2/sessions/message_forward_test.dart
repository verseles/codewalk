import 'dart:async';

import 'package:codewalk/features/sessions/message_forward.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_selection.dart';
import 'package:codewalk/shared/sessions/session_turn_actions.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'composer_fakes.dart';
import 'live_fakes.dart';

// #542: a message sent on to other conversations, one at a time.

const _host = HostId('h');

SessionRef _ref(String id, {HostId host = _host}) =>
    SessionRef(host, const HarnessInstanceId('opencode'), 'ses_$id');

SessionSummary _row(
  String id, {
  String? directory = '/work/app',
  String? title,
  String? parent,
  HostId host = _host,
  DateTime? updated,
  DateTime? archived,
}) => SessionSummary(
  info: SessionInfo(
    ref: _ref(id, host: host),
    title: title ?? 'Title $id',
    ownership: const OwnershipInfo.unknown(reason: 'test'),
    lineage: SessionLineage(parent: parent == null ? null : _ref(parent)),
    project: directory == null ? null : ProjectRef(host, directory),
  ),
  updatedAt: updated ?? DateTime.utc(2026, 11, 1),
  archivedAt: archived,
);

ItemMeta _meta(String id) => ItemMeta(
  id: ItemId('test/$id'),
  generation: 'test',
  status: const OpenValue.known(ItemStatus.completed),
  source: SourceProvenance(
    harness: const HarnessRef(_host, HarnessInstanceId('opencode')),
    version: '2.0.22',
    nativeType: 'test',
  ),
);

final class _Port implements SessionTurnActionPort {
  @override
  SessionTurnState state = const SessionTurnState();

  void stageUndo() => state = SessionTurnState(
    revert: RevertState(
      kind: const OpenValue.known(RevertKind.staged),
      boundary: const ItemId('test/u'),
      anchor: MessageAnchor(message: MessageRef('msg_1'), orderKey: 'msg_1'),
    ),
  );

  @override
  SessionTurnUnavailable? unavailable(SessionTurnAction action) => null;

  // A forward never mutates turns.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('only a whole message with text goes', () {
    expect(
      forwardableText(
        UserInput(
          meta: _meta('u'),
          text: 'please fix it',
          delivery: const OpenValue.known(DeliveryState.delivered),
          confirmed: true,
        ),
      ),
      'please fix it',
    );
    // A prompt the server has not confirmed yet stays.
    expect(
      forwardableText(
        UserInput(
          meta: _meta('u'),
          text: 'please fix it',
          delivery: const OpenValue.known(DeliveryState.delivered),
        ),
      ),
      isNull,
    );
    expect(
      forwardableText(
        AssistantText(meta: _meta('a'), text: 'done', complete: true),
      ),
      'done',
    );
    expect(
      forwardableText(
        AssistantText(meta: _meta('a'), text: 'still', complete: false),
      ),
      isNull,
    );
    expect(
      forwardableText(
        AssistantText(
          meta: _meta('a'),
          text: 'tail',
          complete: true,
          prefixMissing: true,
        ),
      ),
      isNull,
    );
    expect(
      forwardableText(
        AssistantText(meta: _meta('a'), text: '  ', complete: true),
      ),
      isNull,
    );
  });

  test('the forwarded text names where it came from', () {
    final source = _row('src', title: '  Fix   the build ');
    final origin = forwardOrigin(source, untitled: 'Untitled');
    expect(origin, 'app / Fix the build');
    expect(
      forwardOrigin(
        _row('x', directory: null, title: ''),
        untitled: 'Untitled',
      ),
      'Untitled',
    );
    expect(
      forwardedText(provenance: 'Forwarded from: $origin', text: '# Hi'),
      'Forwarded from: app / Fix the build\n\n# Hi',
    );
  });

  test('targets: other top-level, live conversations of the server', () {
    final source = _ref('src');
    final rows = [
      _row('src'),
      _row('child', parent: 'src'),
      _row('other', host: const HostId('elsewhere')),
      _row('archived', archived: DateTime.utc(2026, 11, 2)),
      for (var i = 0; i < 25; i++)
        _row('s$i', updated: DateTime.utc(2026, 10, 1).add(Duration(hours: i))),
    ];
    final groups = forwardTargetGroups(
      directories: ['/work/app', '/work/lib'],
      rowsOf: (directory) => directory == '/work/app' ? rows : null,
      source: source,
    );
    expect(groups.first.rows, hasLength(20));
    // The most recent first.
    expect(groups.first.rows!.first.info.ref, _ref('s24'));
    expect(
      groups.first.rows!.map((row) => row.info.ref.nativeId),
      isNot(anyOf(contains('ses_src'), contains('ses_child'))),
    );
    // A project whose conversations are still read.
    expect(groups.last.rows, isNull);
    final found = forwardTargetGroups(
      directories: ['/work/app'],
      rowsOf: (_) => rows,
      source: source,
      query: 'S3',
    );
    expect(found.single.rows!.map((row) => row.info.ref.nativeId), ['ses_s3']);
    // The project's name finds all of them.
    expect(
      forwardTargetGroups(
        directories: ['/work/app'],
        rowsOf: (_) => rows,
        source: source,
        query: 'APP',
      ).single.rows,
      hasLength(20),
    );
  });

  group('the run', () {
    late FakeOutbox outbox;
    late Map<SessionRef, LiveHandle> handles;
    late List<String> events;
    late Set<SessionRef> gone;
    _Port? port;

    setUp(() {
      outbox = FakeOutbox();
      handles = {};
      events = [];
      gone = {};
      port = null;
    });

    Future<SessionLiveHandle> open(SessionRef ref) async {
      // One lease at a time: the previous ones are closed.
      expect(handles.values.every((handle) => handle.closes == 1), isTrue);
      events.add('open ${ref.nativeId}');
      final handle = LiveHandle(ref, outbox: outbox, turnActions: port)
        ..emit(
          SessionLiveView(
            session: ref,
            phase: SessionLivePhase.live,
            state: liveState(ref),
          ),
        );
      handles[ref] = handle;
      return handle;
    }

    MessageForwardRun run(
      List<String> ids, {
      bool Function()? offline,
      Future<bool> Function(SessionRef session)? confirm,
      Duration timeout = const Duration(seconds: 20),
    }) => MessageForwardRun(
      text: 'Forwarded from: app / Src\n\nhello',
      targets: [for (final id in ids) _row(id)],
      open: open,
      available: (ref) => !gone.contains(ref),
      confirm: confirm,
      offline: offline,
      readyTimeout: timeout,
    );

    test('each target in turn, queued, with its lease closed', () async {
      final forward = run(['a', 'b']);
      await forward.run();
      expect(events, ['open ses_a', 'open ses_b']);
      expect(outbox.calls, hasLength(2));
      expect(
        outbox.calls.first,
        endsWith('queue Forwarded from: app / Src\n\nhello'),
      );
      expect(handles.values.every((handle) => handle.closes == 1), isTrue);
      expect(forward.allDone, isTrue);
      expect(forward.targets.first.status, ForwardStatus.queued);
    });

    test('outcomes: delivered, rejected, uncertain, refused', () async {
      outbox.submitState = SubmissionKind.delivered;
      final delivered = run(['a']);
      await delivered.run();
      expect(delivered.targets.single.status, ForwardStatus.sent);

      outbox.submitState = SubmissionKind.rejected;
      final rejected = run(['b']);
      await rejected.run();
      expect(rejected.targets.single.status, ForwardStatus.failed);
      expect(rejected.targets.single.miss, ForwardMiss.refused);
      expect(outbox.calls.last, startsWith('dismiss'));

      outbox.submitState = SubmissionKind.uncertain;
      final uncertain = run(['c']);
      await uncertain.run();
      expect(uncertain.targets.single.status, ForwardStatus.unconfirmed);
      // Never dismissed, never sent again, even by Retry.
      final calls = outbox.calls.length;
      await uncertain.retryFailed();
      expect(outbox.calls, hasLength(calls));
      expect(outbox.calls.last, startsWith('submit'));

      outbox.submitRefusal = 'full';
      final refused = run(['d']);
      await refused.run();
      expect(refused.targets.single.miss, ForwardMiss.capacity);
    });

    test('Retry sends again only where nothing was sent', () async {
      gone.add(_ref('b'));
      final forward = run(['a', 'b']);
      await forward.run();
      expect(forward.targets.last.miss, ForwardMiss.gone);
      expect(outbox.calls, hasLength(1));
      gone.clear();
      await forward.retryFailed();
      expect(outbox.calls, hasLength(2));
      expect(outbox.calls.last, contains('submit'));
      expect(forward.allDone, isTrue);
    });

    test('offline: nothing opens', () async {
      final forward = run(['a', 'b'], offline: () => true);
      await forward.run();
      expect(events, isEmpty);
      expect(
        forward.targets.map((target) => target.miss),
        everyElement(ForwardMiss.offline),
      );
    });

    test('a staged undo is never committed by a forward', () async {
      port = _Port()..stageUndo();
      final forward = run(['a']);
      await forward.run();
      expect(outbox.calls, isEmpty);
      expect(forward.targets.single.miss, ForwardMiss.busy);
    });

    test('a conversation that stays busy times out unsent', () async {
      final forward = MessageForwardRun(
        text: 'x',
        targets: [_row('a')],
        open: (ref) async {
          final handle = LiveHandle(ref, outbox: outbox)
            ..selectionState = const SessionSelectionState(
              phase: SessionSelectionPhase.pending,
            )
            ..emit(
              SessionLiveView(
                session: ref,
                phase: SessionLivePhase.live,
                state: liveState(ref),
              ),
            );
          handles[ref] = handle;
          return handle;
        },
        available: (_) => true,
        readyTimeout: const Duration(milliseconds: 50),
      );
      await forward.run();
      expect(outbox.calls, isEmpty);
      expect(forward.targets.single.miss, ForwardMiss.busy);
      expect(handles.values.single.closes, 1);
    });

    test(
      'Stop leaves the rest unsent; the one posting ends as it does',
      () async {
        final hold = outbox.holdSubmit = Completer<void>();
        final forward = run(['a', 'b']);
        final running = forward.run();
        await pumpEventQueue();
        forward.stop();
        hold.complete();
        await running;
        // Checked again right before the post, the stop keeps it from going.
        expect(forward.targets.first.status, ForwardStatus.stopped);
        expect(forward.targets.last.status, ForwardStatus.stopped);
        expect(events, ['open ses_a']);
        expect(handles.values.single.closes, 1);
      },
    );

    test('Stop ends at once the wait of the target in progress', () async {
      final forward = MessageForwardRun(
        text: 'x',
        targets: [_row('a'), _row('b')],
        open: (ref) async {
          final handle = LiveHandle(ref, outbox: outbox)
            ..selectionState = const SessionSelectionState(
              phase: SessionSelectionPhase.pending,
            )
            ..emit(
              SessionLiveView(
                session: ref,
                phase: SessionLivePhase.live,
                state: liveState(ref),
              ),
            );
          handles[ref] = handle;
          return handle;
        },
        available: (_) => true,
        readyTimeout: const Duration(hours: 1),
      );
      final running = forward.run();
      await pumpEventQueue();
      forward.stop();
      await running.timeout(const Duration(seconds: 1));
      expect(forward.targets.map((target) => target.status), [
        ForwardStatus.stopped,
        ForwardStatus.stopped,
      ]);
      expect(handles.values.single.closes, 1);
    });

    test('Stop while a lease opens closes it when it comes', () async {
      final opening = Completer<SessionLiveHandle>();
      final forward = MessageForwardRun(
        text: 'x',
        targets: [_row('a')],
        open: (_) => opening.future,
        available: (_) => true,
        readyTimeout: const Duration(hours: 1),
      );
      final running = forward.run();
      await pumpEventQueue();
      forward.stop();
      await running.timeout(const Duration(seconds: 1));
      expect(forward.targets.single.status, ForwardStatus.stopped);
      final late = LiveHandle(_ref('a'), outbox: outbox);
      opening.complete(late);
      await pumpEventQueue();
      expect(late.closes, 1);
      expect(outbox.calls, isEmpty);
    });

    test('a hold that comes before the post keeps it unsent', () async {
      final hold = outbox.holdSubmit = Completer<void>();
      final forward = run(['a']);
      final running = forward.run();
      await pumpEventQueue();
      handles.values.single.selectionState = const SessionSelectionState(
        phase: SessionSelectionPhase.pending,
      );
      hold.complete();
      await running;
      expect(forward.targets.single.miss, ForwardMiss.busy);
    });

    test('an error once the post started is never sent again', () async {
      outbox.submitError = TimeoutException('no answer');
      final forward = run(['a']);
      await forward.run();
      expect(forward.targets.single.status, ForwardStatus.unconfirmed);
      final calls = outbox.calls.length;
      await forward.retryFailed();
      expect(outbox.calls, hasLength(calls));
    });

    test('the server tells of an archive the list has not seen', () async {
      final archived = run(['a'], confirm: (_) async => false);
      await archived.run();
      expect(archived.targets.single.miss, ForwardMiss.gone);
      final unknown = run(['b'], confirm: (_) async => throw StateError('x'));
      await unknown.run();
      expect(unknown.targets.single.miss, ForwardMiss.unavailable);
      expect(outbox.calls, isEmpty);
    });

    test('a lease no longer live before the post keeps it unsent', () async {
      final hold = outbox.holdSubmit = Completer<void>();
      final forward = run(['a']);
      final running = forward.run();
      await pumpEventQueue();
      final handle = handles.values.single;
      handle.emit(
        SessionLiveView(
          session: handle.session,
          phase: SessionLivePhase.live,
          stale: true,
          state: liveState(handle.session),
        ),
      );
      hold.complete();
      await running;
      expect(forward.targets.single.miss, ForwardMiss.busy);
    });

    test('an unexpected error fails only its own target', () async {
      final forward = MessageForwardRun(
        text: 'x',
        targets: [_row('a'), _row('b')],
        open: (ref) async {
          if (ref.nativeId == 'ses_a') throw StateError('broken');
          return open(ref);
        },
        available: (_) => true,
      );
      await forward.run();
      expect(forward.targets.first.miss, ForwardMiss.unavailable);
      expect(forward.targets.last.status, ForwardStatus.queued);
    });

    test('a lease that cannot open says why', () async {
      final forward = MessageForwardRun(
        text: 'x',
        targets: [_row('a'), _row('b')],
        open: (ref) async => throw SessionLiveException(
          ref.nativeId == 'ses_a'
              ? SessionLiveFailure.capacity
              : SessionLiveFailure.notFound,
        ),
        available: (_) => true,
      );
      await forward.run();
      expect(forward.targets.map((target) => target.miss), [
        ForwardMiss.capacity,
        ForwardMiss.gone,
      ]);
    });
  });
}
